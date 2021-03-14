require 'peml/loader'
require 'peml/parser'
require 'peml/emitter'
require 'peml/utils'

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
    value = Peml::Loader.new.load(peml)
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
    peml
  end


  # -------------------------------------------------------------
  # convert markdown or other markup formats to html in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  # currently, not implemented
  def self.render_to_html(peml)
    peml
  end


  # -------------------------------------------------------------
  # parse PEMLtest text input into a data structure
  def self.pemltest_parse(pemltest: nil, filename: nil)
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
