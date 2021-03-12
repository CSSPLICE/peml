require 'peml/loader'
require 'peml/parser'
require 'peml/emitter'
require 'peml/utils'

module Peml
  #~ Class methods ...........................................................


  # -------------------------------------------------------------
  def self.parse(params = {})
    if params[:filename]
      peml = File.open(params[:filename])
    else
      peml = params[:peml]
    end
    value = Peml::Loader.new.load(peml)
    if !params[:result_only]
      diags = Utils.unpack_schema_diagnostics(Utils.schema.validate(value))
    end
    if params[:interpolate]
      value = Peml::interpolate(value)
    end
    if params[:render_to_html]
      value = Peml::render_to_html(value)
    end
    if params[:inline]
      value = Peml::inline(value)
    end
    if params[:result_only]
      value
    else
      { value: value, diagnostics: diags }
    end
  end


  # -------------------------------------------------------------
  # handle mustache variable interpolation
  # currently, not implemented
  def self.interpolate(peml)
    peml
  end


  # -------------------------------------------------------------
  # convert markdown or other markup formats to html
  # currently, not implemented
  def self.render_to_html(peml)
    peml
  end


  # -------------------------------------------------------------
  # inline external file contents
  # currently, not implemented
  def self.inline(peml)
    peml
  end


  # -------------------------------------------------------------
  def self.pemltest_parse(pemltest: nil, filename: nil)
    if filename
      pemltest = File.open(filename)
    end
    Peml::PemlTestParser.new.parse(pemltest)
  end


  # -------------------------------------------------------------
  def self.to_peml(value)
    Peml::Emitter.new.emit(value)
  end

end
