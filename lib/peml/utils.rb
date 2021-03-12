require 'json_schemer'
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
        phrase = 'missing key'
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

  end
end
