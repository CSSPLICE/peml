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
  def self.parse(params = {}, language: nil)
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
    if(value.key?("assets") || (value.key?("systems") && value["systems"][0].key?("suites")))
      value = Peml::DatadrivenTestRenderer.new.generate_tests(value)
    end
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
  # will not be implemented
  def self.inline(peml)
    peml
  end


  # -------------------------------------------------------------
  # handle mustache variable interpolation in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  def self.interpolate(peml)
    default_peml = Marshal.load(Marshal.dump(peml)).dottie!
    puts Utils.handle_exclusion(default_peml, Utils.recurse_hash(peml, :interpolate_helper, default_peml).dottie!)
  end


  # -------------------------------------------------------------
  # convert markdown or other markup formats to html in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
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

end
