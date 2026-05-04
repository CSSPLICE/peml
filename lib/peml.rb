require_relative 'peml/loader'
require_relative 'peml/parser'
require_relative 'peml/emitter'
require_relative 'peml/utils'
require_relative 'peml/peml_test_renderer'
require_relative 'peml/datadriven_test_renderer'
<<<<<<< HEAD
require_relative 'pif/parser'
require_relative 'pif/converter'
=======
require_relative 'pif/converter'
require_relative 'pif/parser'
>>>>>>> pif

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
<<<<<<< HEAD
  def self.parse(params)
    params = params.transform_keys(&:to_sym) rescue params
=======
  def self.parse(language: nil, **params)
>>>>>>> pif
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
<<<<<<< HEAD

    # test renderer requires inline data files
    if params[:render_tests]
      params[:inline_data_files] = true 
=======
    # Should we provide a param to render test cases?
    value = Peml::DatadrivenTestRenderer.new.generate_tests(value)
    if !params[:result_only]
      diags = validate(value)
>>>>>>> pif
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
    # pif  = {}, Takes string as {pif:"content"}
    # or filename as {filename:"./file.peml"}
    if params[:pif]
      parsed_pif = PifParser.parse({ pif: params[:pif] })
    else
      return "Error: pif not parsed"
    end
    
    parsed_pif[:value] = PifParser.markdown_renderer(parsed_pif[:value])

    if params[:result_only]
      parsed_pif[:value]
    else
      parsed_pif
    end

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
