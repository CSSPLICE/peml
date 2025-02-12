require_relative "../peml"
require 'dottie/ext'

module Pif 

  # -------------------------------------------------------------
    def self.parse(params = {})
      if params[:filename]
        file = File.open(params[:filename])
        begin
          pif = file.read
        ensure
          file.close
        end
      else
        pif = params[:pif]
      end

      value = Peml::Loader.new.load(pif).dottie!

      if !params[:result_only]
        schema_path = Pathname.new("#{File.dirname(File.expand_path(__FILE__))}/schema/PIF.json")
        schema = JSONSchemer.schema(schema_path); 
        diags = Peml::Utils.unpack_schema_diagnostics(schema.validate(value));

        block_content = value['assets.code.starter.files[0].content']

        # Further validation (beyond JSON schema) 
        # Only appears after structural issues are resolved
        if (diags.empty? && block_content)
          check_invalid_block_refs(block_content).each do |err| 
            diags << err
          end

        end

      end

      # Other options possible (ex. rendering/hashifying tests)

      if params[:result_only]
        value
      else
        { value: value, diagnostics: diags }
      end

    end 

    # -------------------------------------------------------------
    # Gets the position and blockid of all valid block entities 
    # (optionally including blocklists). 
    def self.get_blockids(block_content, lists = false) 
      blockids = []

      block_content.each_with_index do |item, i| 
        if (item['blockid']) 
          next if item['blocklist'] && lists == false
          blockids << {index: i, id: item['blockid']}
        end 

      end 

      blockids 
    end

    # -------------------------------------------------------------
    # Gets the dependencies of all valid block entities 
    def self.get_blockdeps(block_content)
      dependencies = []

      block_content.each_with_index do |item, i| 
        if (!item['blocklist'] && item['depends']) 
          dependencies << {index: i, deps: item['depends'].gsub(/\s+/, '').split(',')}
        end 

      end 

      dependencies
    end

    # -------------------------------------------------------------
    # Generates error messages based on invalid block references. 
    def self.check_invalid_block_refs(block_content)
      blockids = get_blockids(block_content).map {|b| b[:id]}
      blockdeps = get_blockdeps(block_content)

      err = []

      blockdeps.each do |b|
        pos = b[:index]
        deps = b[:deps]

        deps.each do |d|
          if (!(blockids.include?(d)) && d != '-1')
            err << "Block dependency '#{d}' is unrecognized at block index #{pos}"
          end
  
          id = block_content[pos]['blockid']
          if (id && id == d)
            err << "Block dependency '#{d}' is self-referential at block index #{pos}"
          end
        end
      end
      
      err
    end

end

