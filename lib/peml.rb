require_relative 'peml/loader'
require_relative 'peml/parser'
require_relative 'peml/emitter'
require_relative 'peml/utils'
require_relative 'peml/peml_test_renderer'
require_relative 'peml/datadriven_test_renderer'

require "dottie/ext"

module Peml

  #~ Class methods ...........................................................
  # -------------------------------------------------------------
  def self.parse(params = {})
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
    raise ArgumentError, "peml cannot be empty or nil" if peml.nil? || peml.empty?
    value = Peml::Loader.new.load(peml)
    #Should we provide a param to render test cases?
    value = Peml::DatadrivenTestRenderer.new.generate_tests(value)
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
  # handle mustache variable interpolation in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  # currently, not implemented
  def self.interpolate(peml)
    default_peml = Marshal.load(Marshal.dump(peml)).dottie!
    Utils.handle_exclusion(
      default_peml,
      Utils.recurse_hash(peml, :interpolate_helper, default_peml).dottie!)
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
  def self.pif_parse(pif)
    # pif  = {}, Takes string as {pif:"content"}
    # or filename as {filename:"./file.peml"}
    PifParser.parse(pif)
  end


  # parsed_pif should be a product of pif.parse
  # format options are 'json' and 'yaml'.
  #   If nil a ruby has is returned.
  def self.pif_to_runestone(parsed_pif, format: nil)
    PifConverter.to_Runestone(parsed_pif, format: format)
  end

end
