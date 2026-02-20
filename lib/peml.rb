require_relative 'peml/loader'
require_relative 'peml/parser'
require_relative 'peml/emitter'
require_relative 'peml/utils'
require_relative 'peml/peml_test_renderer'
require_relative 'peml/datadriven_test_renderer'

require 'dottie/ext'
require 'open-uri'

module Peml

  # Ordered pipeline of optional transformation steps.
  # Each entry maps a params key to the method that performs it.
  TRANSFORMS = {
    inline:            -> (v) { Peml.inline(v) },
    inline_data_files: -> (v) { Peml.inline_data_files(v) },
    render_tests:      -> (v) { Peml::DatadrivenTestRenderer.new.render_datadriven_tests!(v) },
    interpolate:       -> (v) { Peml.interpolate(v) },
    render_to_html:    -> (v) { Peml.render_to_html(v) },
  }.freeze


  #~ Class methods ..........................................................

  # -------------------------------------------------------------
  def self.parse(params = {}, more_params = {})
    params = params.merge(more_params)
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

    # Apply requested transformation steps in pipeline order
    TRANSFORMS.each do |key, transform|
      value = transform.call(value) if params[key]
    end

    if params[:result_only]
      value
    else
      { value: value, diagnostics: validate(value) }
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
  # currently, not implemented
  def self.inline(peml)
    peml
  end


  # -------------------------------------------------------------
  # inline structured data file contents into native PEML structured
  # data
  def self.inline_data_files(peml)
    Utils.deep_transform_files!(peml, :inline_data_file)
  end


  # -------------------------------------------------------------
  # handle mustache variable interpolation in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  # currently, not implemented
  def self.interpolate(peml)
    default_peml = Marshal.load(Marshal.dump(peml)).dottie!
    Utils.handle_exclusion(
      default_peml,
      Utils.deep_transform_values!(peml, :interpolate_helper, default_peml).dottie!)
  end


  # -------------------------------------------------------------
  # convert markdown or other markup formats to html in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  # currently, not implemented
  def self.render_to_html(peml)
    Utils.deep_transform_values!(peml, :render_helper)
  end


  # -------------------------------------------------------------
  # parse PEMLtest text input into a data structure
  def self.pemltest_parse(pemltest, filename: nil)
    if filename
      file = File.open(filename)
      begin
        pemltest = file.read
      ensure
        file.close
      end
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
  def self.pif_parse(pif)
    # pif  = {}, Takes string as {pif:"content"}
    # or filename as {filename:"./file.peml"}
    PifParser.parse(pif)
  end


  # -------------------------------------------------------------
  # parsed_pif should be a product of pif.parse
  # format options are 'json' and 'yaml'.
  #   If nil a ruby has is returned.
  def self.pif_to_runestone(parsed_pif, format: nil)
    PifConverter.to_Runestone(parsed_pif, format: format)
  end

end
