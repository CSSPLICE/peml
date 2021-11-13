require 'peml/loader'
require 'peml/parser'
require 'peml/emitter'
require 'peml/utils'

require "kramdown"
require 'kramdown-parser-gfm'

module Peml
  # Class Variables
  @@pemlGlobal = ""
  @@subHash = {}
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
    @@pemlGlobal = value
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
    peml.each do |key, value|
      if !(@@pemlGlobal.key?("exclude") && @@pemlGlobal["exclude"].include?(key))
        if value.is_a?(Hash)
          Peml::interpolate(value)
        elsif value.is_a?(Array)
          value.length.times do |i|
            if value[i].is_a?(Hash) || value[i].is_a?(Array)
              Peml::interpolate(value[i])
            elsif value[i].match(/\{\{(.*?)\}\}/)
              arr = value[i].scan(/\{\{(.*?)\}\}/).flatten
              substitute_values = Peml::interpolate_helper(arr)
              value[i] = value[i].gsub(/\{\{(.*?)\}\}/) { |x| substitute_values[x] }
            end
          end
        elsif value.respond_to?(:to_s) || value.respond_to(:to_i)
          if value.match(/\{\{(.*?)\}\}/)
            arr = value.scan(/\{\{(.*?)\}\}/).flatten
            substitute_values = Peml::interpolate_helper(arr)
            peml[key] = value.gsub(/\{\{(.*?)\}\}/) { |x| substitute_values[x] }
          end
        end
      else
        peml[key] = value
      end
    end
  end


  # -------------------------------------------------------------
  # convert markdown or other markup formats to html in fields inside
  # a PEML data structure (parsed PEML structured as a nested hash)
  def self.render_to_html(peml)
    peml.each do |key, value|
      if value.is_a?(Hash)
        Peml::render_to_html(value)
      elsif value.is_a?(Array)
        value.each do |element|
          Peml::render_to_html(element)
        end
      elsif value.respond_to?(:to_s) || value.respond_to(:to_i)
        peml[key]=Peml::render_helper(value)
      end
    end
  end

  
  def self.render_helper(value)
    return Kramdown::Document.new(value, :auto_ids => false, input: 'GFM').to_html
  end
  

  def self.interpolate_helper(arr)
    substituteValues={}
    arr.length.times do |i|
      if @@subHash.key?(arr[i])
        substituteValues["{{"+arr[i]++"}}"] = @@subHash[arr[i]]
      else
        keys = arr[i].split(".")
        val = @@pemlGlobal
        keys.each do |key|
          if key.include? "["
            indx = key[key.index('[')+1, key.index(']')].to_i
            val = val[key[0, key.index('[')]][indx]
          else
            val = val[key]
          end
        end
        @@subHash[arr[i]] = val
        subKey = "{{"+arr[i]++"}}"
        substituteValues[subKey] = val
      end
    end
    return substituteValues
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
