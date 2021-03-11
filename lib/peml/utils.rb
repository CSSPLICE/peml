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
      result = []
      diags.each do |v|
        err = {}
        v.each do |k, v|
          if !v.empty? && !k.match(/^(data|schema|root_schema|schema_pointer)$/)
            err[k] = v
          end
        end
        result.unshift(err)
      end
      result
    end

  end
end
