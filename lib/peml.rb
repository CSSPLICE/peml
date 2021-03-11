require 'peml/loader'
require 'peml/parser'
require 'peml/emitter'
require 'peml/utils'

module Peml
  #~ Class methods ...........................................................


  # -------------------------------------------------------------
  def self.parse(peml: nil, filename: nil,
    interpolate: false, render_to_html: false, inline: false)
    if filename
      peml = File.open(filename)
    end
    value = Peml::Loader.new.load(peml)
    diags = Utils.unpack_schema_diagnostics(Utils.schema.validate(value))
    if interpolate
      value = Peml::interpolate(value)
    end
    if render_to_html
      value = Peml::render_to_html(value)
    end
    if inline
      value = Peml::inline(value)
    end
    { value: value, diagnostics: diags }
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
