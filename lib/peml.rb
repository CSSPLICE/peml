require 'peml/loader'
require 'peml/parser'
require 'peml/emitter'
require 'peml/utils'
require 'peml/tester'

require "dottie/ext"
require "kramdown"
require 'kramdown-parser-gfm'

module Peml
  # Class Variables
  @@pemlGlobal = ""
  @@subHash = {}
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
    ##how to parse the two differently
    #value = Peml::Loader.new.load(peml)
    value = Peml::pemltest_parse(peml)
    if(value.key?(:givens) || value.key?(:whens) || value.key?(:thens))
      value = Peml::Tester.new.generate_tests_from_dsl(value, language)
    elsif(value.key?("assets") || (value.key?("systems") && value["systems"][0].key?("suites")))
      value = Peml::Tester.new.generate_tests(value)
    end
    @@pemlGlobal = Marshal.load(Marshal.dump(value)).dottie!
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
    peml = Peml::recurse_hash(peml, "interpolate")
    peml = peml.dottie!
    peml = Peml::handle_exclusion(peml)
  end


  # -------------------------------------------------------------
  # convert markdown or other markup formats to html in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  def self.render_to_html(peml)
    peml = Peml::recurse_hash(peml, "render_to_html")
  end


   # -------------------------------------------------------------
   # recurse through the nested hash and perform specified operation
   # on values. Traversal and operations are loosely coupled to support
   # future changes and updates
  def self.recurse_hash(peml, operation)
    peml.each do |key, value|
      if value.is_a?(Hash)
        Peml::recurse_hash(value, operation)
      elsif value.is_a?(Array)
        value.length.times do |i|
          if value[i].is_a?(Hash)
            Peml::recurse_hash(value[i], operation)
          elsif value[i].respond_to?(:to_s) || value[i].respond_to(:to_i)
            if operation == "interpolate"
              peml[key][i] = Peml::interpolate_helper(value[i])
            elsif operation == "render_to_html"
              peml[key][i] = Peml::render_helper(value[i])
            end
          end
        end
      elsif value.respond_to?(:to_s) || value.respond_to(:to_i)
        if operation == "interpolate"
          peml[key] = Peml::interpolate_helper(value)
        elsif operation == "render_to_html"
          peml[key] = Peml::render_helper(value)
        end
      end
    end
  end

  
  def self.render_helper(value)
    return Kramdown::Document.new(value, :auto_ids => false, input: 'GFM').to_html
  end

  
  def self.interpolate_helper(value)
    if value.match(/\{\{(.*?)\}\}/)
      arr = value.scan(/\{\{(.*?)\}\}/).flatten
      substitute_values = Peml::substitute_variables(arr)
      value = value.gsub(/\{\{(.*?)\}\}/) { |x| substitute_values[x] }
    end
    return value
  end


  def self.substitute_variables(arr)
    substitute_values={}
    arr.length.times do |i|
      if @@subHash.key?(arr[i])
        substitute_values["{{"+arr[i]++"}}"] = @@subHash[arr[i]]
      else
        @@subHash[arr[i]] = @@pemlGlobal[arr[i]]
        substitute_values["{{"+arr[i]++"}}"] = @@pemlGlobal[arr[i]]
      end
    end
    return substitute_values
  end


  def self.handle_exclusion(peml)
    if @@pemlGlobal.key?("exclude")
      peml["exclude"].each do |element|
        peml[element]=@@pemlGlobal[element]
      end
    end
    return peml
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
