require 'json_schemer'
require "dottie/ext"
require "kramdown"
require 'kramdown-parser-gfm'
require_relative 'version'

module Peml
  module Utils

    # Return a directory with the project libraries.
    def self.gem_libdir
      ["#{File.dirname(File.expand_path(__FILE__))}",
       "#{Gem.dir}/gems/#{NAME}-#{VERSION}/lib/#{NAME}"].each do |i|
        puts "checking #{i}"
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
    # recurse through the nested hash and perform specified operation
    # on values. Traversal and operations are loosely coupled to support
    # future changes and updates
    def self.recurse_hash(peml, operation, default_peml)
      peml.each do |key, value|
        if value.is_a?(Hash)
          Utils.recurse_hash(value, operation, default_peml)
        elsif value.is_a?(Array)
          value.length.times do |i|
            if value[i].is_a?(Hash)
              Utils.recurse_hash(value[i], operation, default_peml)
            elsif value[i].respond_to?(:to_s) || value[i].respond_to(:to_i)
              peml[key][i] = method(operation).call(value[i], default_peml)
            end
          end
        elsif value.respond_to?(:to_s) || value.respond_to(:to_i)
          peml[key] = method(operation).call(value, default_peml)
        end
      end
    end

    # kramdown parser has changed to add \n idky why, needs fixing
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
      substitute_values = {}
      arr.length.times do |i|
        substitute_values["{{" + arr[i] + +"}}"] = default_peml[arr[i]]
      end
      substitute_values
    end

    def self.handle_exclusion(unchanged_peml, peml)
      if unchanged_peml.key?("exclude")
        peml["exclude"].each do |element|
          peml[element] = unchanged_peml[element]
        end
      end
      peml
    end

    # -------------------------------------------------------------
    # Used to removed matching start/end single- or double-quotes from
    # a string literal. Used in AST cleanup transforms for parslet parsers.
    def self.unquote(s)
      if s.start_with?('"') && s.end_with?('"') ||
        s.start_with?("'") && s.end_with?("'")
        s[1..-2]
      else
        s
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
          result[k] = string_reduce(v)
        end
      elsif tree.is_a? Array
        result = Array.new
        text = nil
        tree.each do |v|
          if v.is_a?(Hash) && v.has_key?(:text)
            if text.nil?
              text = v[:text]
            else
              text += v[:text]
            end
          elsif v.is_a?(String)
            if text.nil?
              text = v
            else
              text += v
            end
          else
            if !text.nil?
              result.push({ text: text })
              text = nil
            end
            result.push(v)
          end
        end
        if !text.nil?
          result.push({ text: text })
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

  end
end
