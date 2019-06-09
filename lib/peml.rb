require 'peml/loader'
require 'peml/parser'

module Peml
  #~ Class methods ...........................................................

  # -------------------------------------------------------------
  def self.load(peml)
    Peml::Loader.new.load(peml)
  end


  # -------------------------------------------------------------
  def self.load_file(filename)
    self.load(File.open(filename))
  end


  # -------------------------------------------------------------
  def self.pemltest_parse(pemltest)
    Peml::PemlTestParser.new.parse(pemltest)
  end


  # -------------------------------------------------------------
  def self.pemltest_parse_file(filename)
    self.pemltest_parse(File.read(filename))
  end

end
