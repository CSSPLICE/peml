require_relative 'peml/loader'
require_relative 'peml/parser'
require_relative 'peml/emitter'
require_relative 'peml/utils'
require_relative 'peml/peml_test_renderer'
require_relative 'peml/datadriven_test_renderer'
require_relative 'pif/converter'
require_relative 'pif/parser'

require "dottie/ext"

module Peml

  #~ Class methods ...........................................................
  # -------------------------------------------------------------
  def self.parse(language: nil, **params)
    if params[:filename]
      file = File.open(params[:filename])
      begin
        peml = file.read
      ensure
        file.close
      end
    else
      peml = params[:peml]
    end
    value = Peml::Loader.new.load(peml)
    # Should we provide a param to render test cases?
    value = Peml::DatadrivenTestRenderer.new.generate_tests(value)
    if !params[:result_only]
      diags = validate(value)
    end
    if params[:inline]
      value = Peml::inline(value)
    end
    if params[:interpolate]
      value = Peml::interpolate(value)
    end
    if params[:render_to_html]
      value = Peml::render_to_html(value)
    end
    if params[:result_only]
      value
    else
      { value: value, diagnostics: diags }
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
  # handle mustache variable interpolation in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  # currently, not implemented
  def self.interpolate(peml)
    default_peml = Marshal.load(Marshal.dump(peml)).dottie!
    Utils.handle_exclusion(default_peml, Utils.recurse_hash(peml, :interpolate_helper, default_peml).dottie!)
  end

  # -------------------------------------------------------------
  # convert markdown or other markup formats to html in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  # currently, not implemented
  def self.render_to_html(peml)
    Utils.recurse_hash(peml, :render_helper, {})
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
  def self.pif_parse(params)
    # pif  = {}, Takes string as {pif:"content"}
    # or filename as {filename:"./file.peml"}
    if params[:pif]
      parsed_pif = PifParser.parse({ pif: params[:pif] })
    else
      return "Error: pif not parsed"
    end
    
    if params[:render_to_html]
      parsed_pif[:value] = PifParser.markdown_renderer(parsed_pif[:value])
    end

    if params[:result_only]
      parsed_pif[:value]
    else
      parsed_pif
    end

  end

  # parsed_pif should be a product of pif.parse
  # format options are 'json' and 'yaml'.
  #   If nil a ruby hash is returned.
  def self.pif_to_runestone(parsed_pif, format = nil)
    if !parsed_pif[:diagnostics].empty?
      # TODO handle this better and return a good error message
      result = parsed_pif[:diagnostics]
      if format == 'json'
        result = result.to_json
      end
    else
      result = PifConverter.to_runestone(parsed_pif[:value], format: format)
    end
    result
  end

end
