require_relative 'peml/loader'
require_relative 'peml/parser'
require_relative 'peml/emitter'
require_relative 'peml/utils'
require_relative 'peml/peml_test_renderer'
require_relative 'peml/datadriven_test_renderer'
require_relative 'pif/parser'
require_relative 'pif/converter'

require 'dottie/ext'
require 'open-uri'

module Peml

  # Ordered pipeline of optional transformation steps.
  # Each entry maps a params key to the method that performs it.
  TRANSFORMS = {
    inline_urls:       -> (state, opts) { Peml.inline_urls(state, opts) },
    inline_data_files: -> (state, opts) { Peml.inline_data_files(state, opts) },
    render_tests:      -> (state, opts) { Peml::DatadrivenTestRenderer.new.render_datadriven_tests!(state, opts) },
    interpolate:       -> (state, opts) { Peml.interpolate(state, opts) },
    render_to_html:    -> (state, opts) { Peml.render_to_html(state, opts) },
  }.freeze


  #~ Class methods ..........................................................

  # -------------------------------------------------------------
  def self.parse(params)
    params = params.transform_keys(&:to_sym) rescue params
    if params[:filename]
      file = File.open(params[:filename])
      begin
        peml = file.read
      ensure
        file.close
      end
    elsif params[:url]
      peml = URI.open(params[:url]).read
    else
      peml = params[:peml]
    end
    raise ArgumentError, "peml cannot be empty or nil" if peml.nil? || peml.empty?
    value = Peml::Loader.new.load(peml)

    # test renderer requires inline data files
    if params[:render_tests]
      params[:inline_data_files] = true 
    end

    diags = params[:result_only] ? nil : validate(value)
    state = { 'value' => value, 'diagnostics' => diags }

    # Apply requested transformation steps in pipeline order
    TRANSFORMS.each do |key, transform|
      if params[key]
        opts = params[:"#{key}_params"] || {}
        state = transform.call(state, opts)
      end
    end

    if params[:result_only]
      state['value']
    else
      state
    end
  end

  # -------------------------------------------------------------
  # Validate a PEML data structure (parsed PEML structured as a nested hash)
  def self.validate(peml)
    Utils.unpack_schema_diagnostics(Utils.schema.validate(peml))
  end

  # -------------------------------------------------------------
  # inline external file contents in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  def self.inline_urls(state, options = {})
    Utils.deep_transform_values!(state, :inline_url_helper)
    state
  end


  # -------------------------------------------------------------
  # inline structured data file contents into native PEML structured
  # data
  def self.inline_data_files(state, options = {})
    Utils.deep_transform_files!(state, :inline_data_file)
    state
  end

  # -------------------------------------------------------------
  # handle mustache variable interpolation in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  # currently, not implemented
  def self.interpolate(state, options = {})
    default_peml = Marshal.load(Marshal.dump(state['value'])).dottie!
    Utils.deep_transform_values!(state, :interpolate_helper, default_peml)
    Utils.handle_exclusion(
      default_peml,
      state['value'].dottie!)
    state
  end

  # -------------------------------------------------------------
  # convert markdown or other markup formats to html in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  # currently, not implemented
  def self.render_to_html(state, options = {})
    Utils.deep_transform_values!(state, :render_helper)
    state
  end

  # -------------------------------------------------------------
  # parse PEMLtest text input into a data structure
  def self.pemltest_parse(params)
    params = params.transform_keys(&:to_sym) rescue params
    if params[:filename]
      file = File.open(params[:filename])
      begin
        pemltest = file.read
      ensure
        file.close
      end
    elsif params[:url]
      pemltest = URI.open(params[:url]).read
    else
      pemltest = params[:pemltest]
    end
    Peml::PemlTestParser.new.parse(pemltest)
  end

  # -------------------------------------------------------------
  # render (unparse) a PEML data structure (parsed PEML structured as a
  # nested hash) into plain-text PEML notation
  def self.to_peml(value)
    Peml::Emitter.new.emit(value)
  end


  # Pif Methods------------------------------------------------------
  def self.pif_parse(params)
    # Accepts string content as {pif: "..."} or a file path as {filename: "..."}
    # Remap :pif to :peml so Peml.parse can accept it
    input = {}
    input[:peml]     = params[:pif]      if params[:pif]
    input[:filename] = params[:filename] if params[:filename]

    # Step 1: Load via PEML parser and run PEML schema validation.
    # result_only is never passed here so PEML diagnostics are always captured.
    state = Peml.parse(input)
    value = state['value'].dottie!
    peml_diags = state['diagnostics'] || []

    # Surface PEML errors immediately — no point running PIF validation
    # on a document that already fails the base PEML structure.
    if peml_diags.any?
      return params[:result_only] ? value : { value: value, diagnostics: peml_diags }
    end

    # Step 2: PIF-specific structural and extended validation
    pif_diags = PifParser.validate(value)

    # Step 3: PIF post-processing (only applied to valid documents)
    PifParser.markdown_renderer(value) if pif_diags.empty?

    params[:result_only] ? value : { value: value, diagnostics: pif_diags }
  end

  # -------------------------------------------------------------
  # parsed_pif should be a product of pif.parse
  # format options are 'json' and 'yaml'.
  #   If nil a ruby hash is returned.
  def self.pif_to_renderable_json(parsed_pif, format = nil)
    if !parsed_pif[:diagnostics].empty?
      # TODO handle this better and return a good error message
      result = parsed_pif[:diagnostics]
      if format == 'json'
        result = result.to_json
      end
    else
      result = PifConverter.to_renderable_json(parsed_pif[:value], format)
    end
    result
  end

end
