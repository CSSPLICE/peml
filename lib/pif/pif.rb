require_relative "../peml"
require 'dottie/ext'

# Need NESTED DAG detection for rejection because Runestone would not be able to support it. (not necessarily in the parser but in this region of code???)
# First block whether list or regular entity must have an empty depends tag (if the depends tag is included)
# Runestone can techinically support blocks with block lists so long as they are pickones 
# For right now we are opting to use the basic-order grader when all the depends tags are empty or not included
# Change the PIF schema so that blocks and blocklists are under one "block entity" that can have an array of other block entites via blocklist 
# The blocklists can also contain a pickone array (only one example - ask about it )
# Maybe check that if a pickone is specified, that it has at least another value for distractor, else its not really necessary 
# Pretty eas yissue I think of having it so that missing [] leads to unintended extended blocks/blocklists. Although, I guess it is valid to have a blocklist inside another blocklist? 
# I don't think that the parsons implementation can handle the fixed_id <-- so we can possibly fail gracefully here 
# doesnot support reusable either 
# Besides the content array, can blocklists be nested? 
# How can I detect the presence of a cycle?  
# Ask if a blocklist can have its own blocklists in it (probably, will have to revise schema)
# Feedback field also indicates that it is a distractor
# Have their be a pickone array instead of pickone attribute 

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
        # Structural validation based on PIF schema 
        schema_path = Pathname.new("#{File.dirname(File.expand_path(__FILE__))}/schema/PIF.json")
        schema = JSONSchemer.schema(schema_path); 
        diags = Peml::Utils.unpack_schema_diagnostics(schema.validate(value));

        # Further validation given correct structure 
        if (diags.empty?)
          block_content = value['assets.code.starter.files[0].content'] # Structurally required
          test_content = value['assets.test.files[0].content'] # Optional 
          test_format = value['assets.test.files[0].format'] # Optional 

          # # Checks that block references are valid 
          # check_invalid_block_refs(block_content).each do |err| 
          #   diags << err


          
          
        end

    

        # Further validation (beyond JSON schema) 
        # Only appears after structural issues are resolved
        # (start)

        # Ensures dependencies match listed blockids and are not self-referential 
        if (diags.empty? && block_content)
          check_invalid_block_refs(block_content).each do |err| 
            diags << err
          end

        end

        # Ensures csv test data is properly formatted 
        if (test_content && test_format && test_format.include?("csv"))
          check_csv_test_content(test_content, !test_format.include?("unquoted")).each do |err| 
            diags << err
          end
        end

        # Notifies that Runestone can not support exercise due to blocklist (Nested DAGs)
        block_content.each do |block|
          if (block['blocklist'])
            diags << "Nested DAGs not supported in Runestone"
            break 
          end
        end
        # (end)
      end


      # Other options possible (ex. rendering/hashifying tests)

      if params[:result_only]
        value
      else
        { value: value, diagnostics: diags }
      end

      # puts value 
      # puts ""
      # puts to_parsons(value)

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

    # -------------------------------------------------------------
    # Generates error messages based on invalid csv quoted test content. 
    # (Other formats later supported)
    def self.check_csv_test_content(test_content, quoted)
      err = []

      lines = test_content.split(/(\r\n|\r|\n)/).map(&:strip).reject(&:empty?)
      header = lines[0]

      # Ensures test header follows <input>,expected,[description] format and 
      # that keywords "expected" and "description" do not repeat
      if (/^.*,expected(,description)?$/.match?(header) && 
        /^(?!expected,expected)(?!description,expected)/.match?(header) == false)
        err << "Content test header '#{header}' is not recognized"
        return err
      end

      # Index position of expected method/function return
      expected_output_index = header.split(",").index("expected")
      lines[1..-1].each_with_index do |line, i|
        entries = quoted \
        ? line.scan(/(?:(\s*,\s*)|\n|^)("(?:(?:"")*[^"]*)*"|[^",\n]*|(?:\n|$))/).map {|match| match[1]} \
        : line.split(","); 

        # Used to debug the correctness of column-splitting regex
        # puts entries 

        # Add more refined validation for proper enclosing of quotes for quoted format ??? 

        if (entries.length - 1 < expected_output_index)
          err << "Content test line #{i+1} does not contain enough columns"
        elsif (entries.length > header.split(",").length)
          err << "Content test line #{i+1} contains extraneous columns"
        end
      end

    err
    end

    def self.to_parsons(pif)
      tags = pif['tags']
      blocks = pif['assets.code.starter.files[0].content']

      parsons_data_model = {
        "question_text" => pif["instructions"], 
        "options" => {
          "grader" => {
            "type" => tags["style"].include?("execute") ? "exec" : "dag", 
            "showFeedback" => true, 
          }, 
          "maxdist" => 0, 
          "order" => "", 
          "noindent" => tags["style"].include?("indent"),
          "adaptive" => true, 
          "numbered" => pif["numbered"] || false, 
          "language" => pif["systems[0].language"],
          "runnable" => true, 
        }, 
        "blocks" => [],
      }.dottie!

      blocks.each do |block|
        block = block.dottie!

        block_data_model = {
          "text" => "", 
          "type" => "", 
          "tag" => "",
          "depends" => "", 
          "displaymath" => true,
        }.dottie!

        has_blocklist = block["blocklist"]

        if has_blocklist && !block["pickone"]
          return nil 
        elsif has_blocklist
          block_data_model["text"] = block["blocklist[0].display"]
          block_data_model["tag"] = block["blocklist[0].blockid"] || ""
          block_data_model["depends"] = block["depends"] || ""
          parsons_data_model["blocks"] << block_data_model

          if (block["blocklist"].length > 1)
            paired_distractor = block["blocklist[1]"]
            paired_distractor_data_model = {
              "text" => paired_distractor["display"], 
              "tag" => "paired", 
              "depends" => "", 
              "displaymath" => "",
            }
            parsons_data_model["blocks"] << paired_distractor_data_model
          end
        else
          block_data_model["text"] = block["display"]

          if block["depends"] == -1 
            block_data_model["type"] = "distractor"
          else 
            block_data_model["tag"] = block["blockid"] || ""
            block_data_model["depends"] = block["depends"] || ""
          end 

          parsons_data_model["blocks"] << block_data_model
        end 
      end
      parsons_data_model
  end
end

