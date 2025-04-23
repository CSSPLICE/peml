require_relative "../peml"
require 'dottie/ext'
require 'csv'

# Notes to self: 
# 1.) Determine whether both blocklist and blocklist[0] and have 
#     depends fields, and if so, what each represents 
# 2.) If using execution-based grading, does PIF require all of the following: 
#     tabular test content, format, wrapper, and pattern_actual 
# 3.) Check for duplicate blockids
# 4.) Currently, I am not sure how my code would be compiled into a Ruby gem 
#     (assuming we're going in that direction). The 

module Parser
  # ------------------------------------------------------------------------------
  # Parses and validates a PIF file/string 
  def self.parse(params = {})
    # Gets file contents 
    if params[:filename]
      file = File.open(params[:filename])
      begin
        pif = file.read
      ensure
        file.close
      end
    # Gets string content 
    else
      pif = params[:pif]
    end

    # Parses PIF 
    value = Peml::Loader.new.load(pif).dottie!

    # Validates PIF 
    if !params[:result_only]
      # Structural validation based on PIF schema 
      schema_path = Pathname.new("#{File.dirname(File.expand_path(__FILE__))}/schema/PIF.json")
      schema = JSONSchemer.schema(schema_path); 
      diags = Peml::Utils.unpack_schema_diagnostics(schema.validate(value));

      # Extended validation
      if (diags.empty?)
        style_tag = value["tags.style"] # Structurally required 
        block_content = value['assets.code.blocks.content'] # Structurally required
        test_content = value['assets.test.files[0].content'] # Optional 

        # Blocks separated by type
        # Altered into format {"pos": block_position, "block": original_block_info}
        s = separate_blocks(block_content)
        normal_blocks = s[0]
        blocklists = s[1]
        distractors = s[2]

        # (replace possibly)
        # Validates that the first block of a blocklist (including "assets.code.blocks.content")
        # has an empty or implicit dependency 
        first_block = block_content[0]
        first_block_deps = first_block["depends"]
        if (!first_block["blocklist"] && first_block_deps && first_block_deps != "")
          diags << "The first block is considered the root of a DAG. It's dependency should be empty or implicit."
        end

        blocklists.each do |blocklist|
          raw_blocklist = blocklist["block"]["blocklist"] # Retreives blocklist's original form before separate_blocks
          root = raw_blocklist[0] # Structurally required
          root_deps = root["depends"]

          if (root["depends"] && root_deps != "")
            diags << "Block at position #{blocklist["pos"]}.1 is considered the root of a DAG. It's dependency should be empty or implicit."
          end
        end

        # Validates that indentation values are provided if required 
        if (style_tag.include?("indent"))
          normal_blocks.each do |block|
            indent = block["block"]["indent"]
            if (!indent)
              diags << "Block at position #{block["pos"]} missing required indent field."
            elsif (Integer(indent) < 0)
              diags << "Block at position #{block["pos"]} uses negative indent."
            end
          end
        end

        # Validates that blockids are unique 
        

        # Validates that all blockids are recognized references 
        diags += validate_blockdeps(block_content)

        # Validates that csv test data is correctly formatted
        if (test_content) 
          parsed_test_content = Peml::CsvUnquotedParser.new.parse(test_content)
          header = parsed_test_content[0]

          parsed_test_content[1..].each_with_index do |row, i|
            if (row.length != header.length)
              diags << "Row #{i} of the test content does not match its header length."
            end
          end
        end
      end
    end

    # Returns parsing hash w/ optional diagnostic messages
    if params[:result_only]
      value
    else
      { value: value, diagnostics: diags }
    end
  end 

  # ------------------------------------------------------------------------------
  # Gets all blockids for non-distractor elements 
  def self.get_blockids(blocks)
    blocks.inject([]) {|ids, block| ids + get_blockids_helper(block)}
  end

  # ------------------------------------------------------------------------------
  # Recursive helper for get_blockids 
  def self.get_blockids_helper(block)
    curr_blockid = block["blockid"]
    blocklist = block["blocklist"]
    depends = block["depends"]

    # Case: Normal block 
    if (!blocklist && curr_blockid && depends != "-1")
      return [curr_blockid]
    end

    # Case: Blocklist 
    if (blocklist)
      # Recursively gets blockids of nested elements 
      blockids = curr_blockid ? [curr_blockid] : []
      blocklist.each do |nested_block| 
        blockids = blockids + get_blockids_helper(nested_block)
      end
      return blockids 
    end

    # Case: Distractor 
    return []
  end

  # ------------------------------------------------------------------------------
  # Gets all block dependences for non-distractor elements 
  def self.get_blockdeps(blocks)
    blocks.inject([]) {|depends, block| depends + get_blockdeps_helper(block)}
  end

  # ------------------------------------------------------------------------------
  # Recursive helper for get_blockdeps
  def self.get_blockdeps_helper(block)
    curr_blockdeps = block["depends"] && block["depends"] != "-1" ? block["depends"].split(/\s*,\s*/) : []
    blocklist = block["blocklist"]

    # Case : Normal block 
    if (!blocklist)
      return curr_blockdeps
    # Case: Blocklist 
    else 
      blockdeps = curr_blockdeps
      # Recursively gets dependencies of all nested elements 
      blocklist.each do |nested_block|
        blockdeps = blockdeps + get_blockdeps_helper(nested_block)
      end
      return blockdeps
    end
  end

  # ------------------------------------------------------------------------------
  # Validates that all block dependencies point to recognized blockids 
  def self.validate_blockdeps(blocks)
    err = [] 
    blockids = get_blockids(blocks)

    blocks.each do |block|
      curr_blockid = block["blockid"]
      curr_deps = get_blockdeps_helper(block)
      if (curr_deps && !curr_deps.all? {|dep| blockids.include?(dep)})
        err << "Block dependency references to [#{curr_deps - blockids}] do not exist."
      end
    end

    return err
  end

  # ------------------------------------------------------------------------------
  # Validates that CSV test content is properly formatted
  def self.validate_test_content(content)
    err = []
    lines = content.lines 

    # Validates header of CSV test content 
    begin 
      # CSV header info 
      header_line = lines.first.strip
      header = CSV.parse_line(header_line)
      header_len = header.length

      # Case: Space characters surrounding comma-separation
      if (invalid_comma_spacing?(header_line))
        err << "Test header contains invalid space characters before/after comma delimiters."
      end 

      # Case: More than 3 header fields 
      if (header_len > 3)
        err << "Test header contains too many fields: #{header_len}."
      end

      # Case: "Expected" field missing
      if ((header[1] != "expected"))
        err << 'Test header missing required "expected" field at index 1.'
      end

      # Case: "Description" field missing
      if (header_len == 3 && (header[2] != "description"))
        err << 'Test header length of 3 requires "description" field at index 2.'
      end
    
    # CSV header parsing failure
    rescue CSV::MalformedCSVError => e 
      err << "Failed to parse CSV test header: #{e.message}"
      return err 
    end 

    # Validates rows of CSV content
    begin 
      lines[1..].each_with_index do |line, i| 
        row = CSV.parse_line(line.strip, headers: header)

        # Case: Space characters surround comma-separation
        if (invalid_comma_spacing?(line))
          err << "Test content line at index #{i} contains invalid space characters before/after comma delimiters."
        end 

        # Case: Mismatch between header and row length
        if (row.length != header_len)
          err << "Test content line at index #{i} contains more/less fields than header."
        end

        # Case: Description value is non-boolean 
        if (row.length == 3 && (!row["description"].match?(/^\s*true$/) && !row["description"].match?(/^\s*false$/))) 
          err << "Test content line at index #{i} contains non-boolean value for 'description' field."
        end
      end
    
    # CSV row content parsing failure 
    rescue CSV::MalformedCSVError => e 
      err << "Failed to parse CSV test content: #{e.message}"
      return err
    end
    return err
  end 

  # ------------------------------------------------------------------------------
  # Helper for validate_test_content. Detects space characters between 
  # CSV entries. 
  def self.invalid_comma_spacing?(line)
    in_quotes = false
    line.chars.each_with_index do |char, i|
      if char == '"'
        # Toggles in_quotes mode unless escape quoting
        in_quotes = !in_quotes unless line[i+1] == '"'
      elsif char == ',' && !in_quotes
        # Checks for space characters after comma delimiters 
        before = line[i - 1] if i > 0
        after  = line[i + 1]
        return true if before =~ /\s/ || after =~ /\s/
      end
    end
    false
  end

  # ------------------------------------------------------------------------------
  # Separates and positionally labels blocks into normal blocks, blocklists, 
  # and distractors. Ex. Blocks nested under first block are labelled as 
  # 1.1, 1.2, and 1.3. 
  def self.separate_blocks(blocks)
    i = 0 

    blocks.inject([[],[],[]]) do |res, block| 
      s = separate_blocks_helper("#{i}", block)
      res[0] += s[0] # normal blocks
      res[1] += s[1] # blocklists 
      res[2] += s[2] # distractors 
      i += 1
      res
    end
  end

  # ------------------------------------------------------------------------------
  # Recursive helper for separate_blocks
  def self.separate_blocks_helper(pos, block)
    norms = []
    blocklists = []
    distractors = []
  
    # Case: Blocklist 
    if (block["blocklist"]) 
      blocklists << {"pos" => pos, "block" => block}
      # Recursively separates nested blocks and merges results 
      block["blocklist"].each_with_index do |nested_block, i| 
        x, y, z = separate_blocks_helper("#{pos}.#{i+1}", nested_block)
        norms += x 
        blocklists += y 
        distractors += z 
      end
    # Case: Distractor
    elsif (block["feedback"] || block["depends"] && block["depends"].match?(/\s*-1\s*/))
      distractors << {"pos" => "#{pos}", "block" => block}
    # Case: Normal block 
    else 
      norms << {"pos" => "#{pos}", "block" => block}
    end
  
    return norms, blocklists, distractors
  end
end