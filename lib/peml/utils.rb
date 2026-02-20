require 'json_schemer'
require "dottie/ext"
require "kramdown"
require 'rexml/document'
require 'kramdown-parser-gfm'
require 'yaml'
require 'json'
require 'csv'
require 'uri'
require_relative 'version'

module Peml
  module Utils

    # Return a directory with the project libraries.
    def self.gem_libdir
      ["#{File.dirname(File.expand_path(__FILE__))}",
           "#{Gem.dir}/gems/#{NAME}-#{VERSION}/lib/#{NAME}"].each do |i|
        # puts "checking #{i}"
        return i if File.readable?(i)
      end
      raise "unable to locate gem lib dir for gem: #{NAME}"
    end

    # Return the JSON Schema for PEML, loaded from the internal definition file
    def self.schema
      if !defined?(@@schema) || @@schema.nil?
        # Cached in a module variable so it is only loaded once
        @@schema = JSONSchemer.schema(Pathname.new(
          self.gem_libdir + '/schema/PEML.json'))
      end
      @@schema
    end

    # extract schema validation info from validator return results
    def self.unpack_schema_diagnostics(diags)
      if diags
        diags.map { |e| human_readable_message_from(e) }
      else
        diags
      end
    end


    # -------------------------------------------------------------
    def self.human_readable_message_from(verr)
      if verr['data_pointer'] && !verr['data_pointer'].empty?
        location = "Path '#{verr['data_pointer']}'"
      else
        location = "The document"
      end

      case verr['type']
      when 'required'
        if verr['details']['missing_keys'].length == 1
          "#{location} is missing key: #{verr['details']['missing_keys'][0]}"
        else
          "#{location} is missing keys: #{verr['details']['missing_keys'].join ', '}"
        end
      when 'format'
        "#{location} is not in the required format (#{verr['schema']['format']})"
      when 'pattern'
        "#{location} does not match the required pattern (#{verr['schema']['pattern']})"
      when 'object'
        "#{location} does not have sub-keys (has the wrong structure)."
      when 'string'
        "#{location} is not a string."
      when 'integer'
        "#{location} is not an integer."
      when 'array'
        "#{location} is not an array (has the wrong structure)."
      when 'minLength'
        "#{location} is not long enough (min #{verr['schema']['minLength']})"
      when 'minimum'
        "#{location} is too low (minimum #{verr['schema']['minimum']})"
      when 'maximum'
        "#{location} is too high (maximum #{verr['schema']['maximum']})"
      else
        err = {}
        verr.each do |k, v|
          # if !v.empty? && !k.match(/^(data|schema|root_schema|schema_pointer)$/)
          if !v.empty? && !k.match(/^(data|root_schema)$/)
            err[k] = v
          end
        end
        "#{location} has a problem. Please check your input.\n#{JSON.pretty_generate(err)}"
      end
    end

    # -------------------------------------------------------------

    # A recursive walker that walks through the hash and transforms files
    # that map to structured data formats (YAML, JSON, CSV, etc.)
    def self.deep_transform_files!(peml, operation)
      peml.each do |key, value|
        if key == 'file' && value.is_a?(Hash)
          peml[key] = method(operation).call(value)
        elsif key == 'files' && value.is_a?(Array)
          value.length.times do |i|
            if value[i].is_a?(Hash)
              peml[key][i] = method(operation).call(value[i])
            end
          end
        elsif value.is_a?(Hash)
          Utils.deep_transform_files!(value, operation)
        elsif value.is_a?(Array)
          value.each do |element|
            Utils.deep_transform_files!(element, operation) if element.is_a?(Hash)
          end
        end
      end
      peml
    end

  # -------------------------------------------------------------
  # deep transform values in a nested hash/array structure
  # Traversal and operations are loosely coupled to support
  # future changes and updates
  def self.deep_transform_values!(peml, operation, default_peml = {})
    peml.each do |key, value|
      if value.is_a?(Hash)
        Utils.deep_transform_values!(value, operation, default_peml)
      elsif value.is_a?(Array)
        value.length.times do |i|
          if value[i].is_a?(Hash)
            Utils.deep_transform_values!(value[i], operation, default_peml)
          elsif value[i].respond_to?(:to_s) || value[i].respond_to?(:to_i)
            peml[key][i] = method(operation).call(value[i], default_peml)
          end
        end
      elsif value.respond_to?(:to_s) || value.respond_to?(:to_i)
        peml[key] = method(operation).call(value, default_peml)
      end
    end
    peml
  end

  #kramdown parser has changed to add \n idky why, needs fixing
  def self.render_helper(value, default_peml)
    Kramdown::Document.new(value, :auto_ids => false, input: 'GFM', hard_wrap: ["false"]).to_html
  end


  def self.interpolate_helper(value, default_peml)
    if value.match(/\{\{(.*?)\}\}/)
      substitute_values = Utils.substitute_variables(value.scan(/\{\{(.*?)\}\}/).flatten, default_peml)
      value = value.gsub(/\{\{(.*?)\}\}/) { |x| substitute_values[x] }
    end
    value
  end


  def self.substitute_variables(arr, default_peml)
    substitute_values={}
    arr.length.times do |i|
      substitute_values["{{"+arr[i]++"}}"] = default_peml[arr[i]]
    end
    substitute_values
  end


  def self.handle_exclusion(unchanged_peml, peml)
    if unchanged_peml.key?("exclude")
      peml["exclude"].each do |element|
        peml[element]=unchanged_peml[element]
      end
    end
    peml
  end


  # -------------------------------------------------------------
  def self.inline_data_file(value)
    if value.is_a?(Hash)
      content = value['content']
      if content.is_a?(String) # Only parse if it's a string
        type = mime_type(value)
        case type
        when 'text/yaml'
          value['content'] = YAML.load(content)
          value.delete('type')
        when 'application/json'
          value['content'] = JSON.parse(content)
          value.delete('type')
        when 'text/csv'
          value['content'] = tabular_to_hashes(CSV.parse(content))
          value.delete('type')
        when 'application/xml', 'text/xml'
          value['content'] = xml_to_hash(REXML::Document.new(content).root)
          value.delete('type')
        when 'text/x-unquoted-csv'
          value['content'] = tabular_to_hashes(Peml::CsvUnquotedParser.new.parse(content))
          value.delete('type')
        end
      end
    end
    value
  end


  # -------------------------------------------------------------
  # convert an array of arrays representing CSV-style row-based data
  # where the first row represents column headings.
  # Returns a new data structure consisting of an array of hashes,
  # one per row, where each hash is a key/value mapping column names
  # to cell values for that row.
  def self.tabular_to_hashes(data)
    result = []
    if data && data.is_a?(Array) && data.length > 0
      headers = data[0]
      (1...data.length).each do |i|
        row = data[i]
        hash = {}
        headers.each_with_index do |header, j|
          hash[header] = row[j]
        end
        result << hash
      end
    end
    result
  end


  # -------------------------------------------------------------
  # Recursively convert a REXML element into a nested hash/array structure.
  def self.xml_to_hash(element)
    return nil if element.nil?
    result = {}
    element.attributes.each do |name, value|
      result["@#{name}"] = value
    end
    element.elements.each do |child|
      child_result = xml_to_hash(child)
      if result[child.name]
        if result[child.name].is_a?(Array)
          result[child.name] << child_result
        else
          result[child.name] = [result[child.name], child_result]
        end
      else
        result[child.name] = child_result
      end
    end
    if result.empty?
      return element.text
    else
      text = element.text ? element.text.strip : nil
      result['content'] = text if text && !text.empty?
      return result
    end
  end


  # -------------------------------------------------------------
  # Used in AST cleanup transforms for parslet parsers to "clean up"
  # nested hashes/arrays of nodes by simplifying values to text strings
  # where possible.
  def self.string_reduce(tree)
    # puts "string_reduce: #{tree.inspect}"
    if tree.is_a? Hash
      result = Hash.new
      tree.each do |k, v|
        result[k] = Utils.string_reduce(v)
      end
    elsif tree.is_a? Array
      result = Array.new
      text = nil
      tree.each do |v|
        if v.is_a?(Hash) && v.has_key?(:text)
          if text.nil?
            text = v[:text].to_s
          else
            text += v[:text].to_s
          end
        elsif v.is_a?(String)
          if text.nil?
            text = v
          else
            text += v
          end
        else
          if !text.nil?
            result.push({text: text})
            text = nil
          end
          result.push(v)
        end
      end
      if !text.nil?
        result.push({text: text})
        text = nil
      end
      if result.length == 1 &&
         result[0].is_a?(Hash) &&
         result[0].has_key?(:text)
        result = result[0][:text]
      end
    else
      result = tree
    end
    result
  end


  # -------------------------------------------------------------
  # Infer the MIME type from a file hash or URL string.
  #
  # If file_hash is a Hash:
  #   - returns the "type" value if present
  #   - otherwise infers from the extension of the "name" value
  # If file_hash is a String matching "url(...)":
  #   - infers from the file extension at the end of the URL path
  # Returns nil if the type cannot be determined.
  MIME_TYPES = {
    '.rb'    => 'text/x-ruby',
    '.py'    => 'text/x-python',
    '.java'  => 'text/x-java',
    '.c'     => 'text/x-csrc',
    '.cpp'   => 'text/x-c++src',
    '.h'     => 'text/x-chdr',
    '.js'    => 'text/javascript',
    '.ts'    => 'text/typescript',
    '.json'  => 'application/json',
    '.xml'   => 'application/xml',
    '.yaml'  => 'text/yaml',
    '.yml'   => 'text/yaml',
    '.md'    => 'text/markdown',
    '.txt'   => 'text/plain',
    '.csv'   => 'text/csv',
    '.csvu'   => 'text/x-unquoted-csv',
    '.csvuq'  => 'text/x-unquoted-csv',
    '.ucsv'   => 'text/x-unquoted-csv',
    '.html'   => 'text/html',
    '.htm'    => 'text/html',
    '.css'    => 'text/css',
    '.csv-unquoted'   => 'text/x-unquoted-csv',
    '.png'   => 'image/png',
    '.jpg'   => 'image/jpeg',
    '.jpeg'  => 'image/jpeg',
    '.gif'   => 'image/gif',
    '.pdf'   => 'application/pdf',
    '.zip'   => 'application/zip',
    '.svg'   => 'image/svg+xml'
  }.freeze

  def self.mime_type(file_hash)
    result = nil
    if file_hash.is_a?(Hash)
      result = file_hash['type'] if file_hash['type']
      result = mime_type_from_filename(file_hash['name']) if file_hash['name'] && result.nil?
    elsif file_hash.is_a?(String)
      if (match = file_hash.match(/\Aurl\((.*)\)\z/))
        url = match[1]
        path = URI.parse(url).path rescue url
        result = mime_type_from_filename(path)
      else
        result = mime_type_from_filename(file_hash)
      end
    end
    if result == 'text/csv-unquoted' || result == 'csv-unquoted'
      result = 'text/x-unquoted-csv'
    end
    result
  end

  def self.mime_type_from_filename(filename)
    ext = File.extname(filename).downcase
    MIME_TYPES[ext]
  end

  end
end
