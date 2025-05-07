require_relative "../peml"
require 'dottie/ext'
require 'csv'

module Parser
  # ------------------------------------------------------------------------------
  # Parses and validates a PIF file/string 
  # Returns a hash structured, by default, as {value: , diags:}
  # or, if result-only is set to true, the equivalent of hash[:value]. 
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

    # Parses content as PEML 
    value = Peml::Loader.new.load(pif).dottie!

    # Validates PEML as PIF
    if !params[:result_only]
      # Structural validation based on PIF schema 
      base_dir = File.dirname(File.expand_path(__FILE__))
      schema_file = "#{base_dir}/schema/PIF.json"
      schema_path = Pathname.new(schema_file)
      schema = JSONSchemer.schema(schema_path); 
      
      sv = schema.validate(value)
      diags = Peml::Utils.unpack_schema_diagnostics(sv)


      # Extended validation
      if (diags.empty?)
        style_tag = value["tags.style"] # Structurally required 
        block_content = value['assets.code.blocks.content'] # Structurally required
        test_content = value['assets.test.files[0].content'] # Optional 
        test_format = value['assets.test.files[0].format'] # Optional
        systems = value['systems'] # Optional 

        # Checks that the required fields for execution-based grading 
        # are included 
        if (style_tag.include?("execute") && (!test_content || !test_format || !systems))
          diags << 'Missing required test content, test format, or language '\
                   'fields for execution-based grading.'
        end

        # Separates blocks into normal blocks, blocklists, and distractors 
        # Separated blocks are given an addition "pos" field
        s = separate_blocks(block_content)
        normal_blocks = s[0]
        blocklists = s[1]
        distractors = s[2]

        if (deps_violation(block_content))
          diags << 'Dependencies must refer to previously defined blocks '\
                    'within the same blocklist scope.'
        end

        # Checks if indentation is required and 
        # if all normal blocks have an indent level
        if (style_tag.include?("indent"))
          normal_blocks.each do |block|
            indent =  block["indent"]
            pos = block["pos"]

            if indent.nil?
              diags << "Block at position #{pos} is missing the required "\
                        "indent field."
            elsif indent.to_i < 0
              diags << "Block at position #{pos} has a negative indent."
            end
            
          end
        end

        # Checks that blockids are unique 
        blockids = get_blockids(block_content)
          .select { |id| id != "fixed" && id != "reusable" }
        if (blockids.length != blockids.uniq.length)
          diags << "Duplicate blockids used."
        end

        # Checks that all blockids are recognized references 
        diags += validate_blockdeps(block_content)

        # Checks that the CSV test content is correctly formatted, 
        # i.e., the header length matches all row lengths 
        if (style_tag.include?("execute") && test_content) 
          parsed_test_content = Peml::CsvUnquotedParser.new.parse(
            test_content
          )
          header = parsed_test_content[0]

          parsed_test_content[1..].each_with_index do |row, i|
            if (row.length != header.length)
              diags << "Row #{i} of the test content does not match "\
                       "its header length."
            end
          end
        end
      end
    end

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
    is_distractor = block["depends"]&.match?(/\s*-1\s*/) || 
        !block["feedback"].nil?

    # Case: Distractor
    if (is_distractor)
      return []
    # Case: Blocklist
    elsif (blocklist)
      # Recursively gets blockids of nested elements 
      blockids = Array(curr_blockid)
      blocklist.each do |nested_block| 
        blockids += get_blockids_helper(nested_block)
      end
      return blockids 
    # Case: Normal block
    else (blocklist)
      return Array(curr_blockid)
    end
  end

  # ------------------------------------------------------------------------------
  # Gets all block dependencies for non-distractor elements 
  def self.get_blockdeps(blocks)
    blocks.inject([]) {|depends, block| depends + get_blockdeps_helper(block)}
  end

  # ------------------------------------------------------------------------------
  # Recursive helper for get_blockdeps
  def self.get_blockdeps_helper(block)
    parsed_depends = block["depends"]&.split(/\s*,\s*/)  || []
    blocklist = block["blocklist"]
    is_distractor = parsed_depends&.include?("-1") ||
        !block["feedback"].nil?
    
    # Case: Distractor
    if (is_distractor)
      return []
    # Case : Blocklist
    elsif (blocklist)
      blockdeps = parsed_depends
      # Recursively gets dependencies of all nested elements 
      blocklist.each do |nested_block|
        blockdeps += get_blockdeps_helper(nested_block)
      end
      return blockdeps
    # Case: Normal block
    else
      return parsed_depends
    end
  end

  # ------------------------------------------------------------------------------
  # Validates that all block dependencies point to recognized blockids 
  def self.validate_blockdeps(blocks)
    errors = [] 
    blockids = get_blockids(blocks)

    blocks.each do |block|
      curr_blockid = block["blockid"]
      curr_deps = get_blockdeps_helper(block)

      if (!(curr_deps - blockids).empty?)
        unrecognized_refs = [curr_deps - blockids]
        errors << "Unknown block dependencies: [#{unrecognized_refs}]"
      end
    end

    return errors
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

    blocklist = block["blocklist"]
    feedback = block["feedback"]
    depends = block["depends"]

    block = block.merge({"pos" => pos})
  
    # Case: Blocklist 
    if (blocklist) 
      blocklists << block
      
      # Recursively separates nested blocks and merges results 
      blocklist.each_with_index do |nested_block, i| 
        x, y, z = separate_blocks_helper("#{pos}.#{i+1}", nested_block)
        norms += x 
        blocklists += y 
        distractors += z 
      end
    # Case: Distractor
    elsif (feedback || depends && depends.match?(/\s*-1\s*/))
      distractors << block
    # Case: Normal block 
    else 
      norms << block
    end
  
    return norms, blocklists, distractors
  end

  # ------------------------------------------------------------------------------
  # Checks whether any blocks form a cycle (replaced by deps_violation())
  def self.has_cycle(blocks) 
    num_blocks = blocks.length 

    # Blockid-to-position mapping
    block_position_lookup = {} 
    blocks.each_with_index do |block, i|
      blockid = block["blockid"]
      has_custom_id = blockid != "fixed" && blockid != "reusable"

      if (blockid && has_custom_id) 
        block_position_lookup[blockid] = i 
      end
    end

    # Position-to-block-dependencies mapping 
    dependencies_lookup = Array.new(num_blocks)
    blocks.each_with_index do |block, i|
      depends = block["depends"]
      
      # Root status (empty dependencies)
      if (!depends)
        dependencies_lookup[i] = []
      # Implicit dependency on previous, non-distractor 
      # block (missing dependencies)
      elsif (depends == "" && i != 0)
        dependencies_lookup[i] = [i - 1]
      # Explicit dependencies 
      else 
        dependencies_lookup[i] = depends 
            .split(/\s*,\s*/)
            .map { |d| block_position_lookup[d] }
      end
    end

    # Number of prerequisites per block  
    count = Array.new(blocks.length, 0)
    # Populates count 
    dependencies_lookup.each do |dependencies|
      dependencies.each do |d|
        count[d] += 1
      end
    end

    # Block processing statuses 
    marked = Array.new(blocks.length, false)
    # Blocks to be processed 
    to_process = []
    # Identifies root blocks 
    blocks.each_with_index do |block, i|
      if (count[i] == 0 && !marked[i])
        to_process << i
      end
    end

    # Continuously processes unmarked blocks 
    # w/ zero current prerequisities 
    while (to_process.length > 0)
      pos = to_process.pop()
      dependencies = dependencies_lookup[pos]

      dependencies.each do |d|
        count[d] -= 1
        if (count[d] == 0)
          to_process << d
        end
      end

      # marks block as explored 
      marked[pos] = true
    end

    return !!marked.index(false)
  end

  # ------------------------------------------------------------------------------
  # Ensures that dependencies reference only prior blocks, and nested blocks
  # only reference blocks in the same list. Prevents cycles as a result. 
  def self.deps_violation(blocks)
    previous_blocks = []
    violation = false
  
    blocks.each_with_index do |block|
      blockid = block["blockid"]
      blocklist = block["blocklist"]
      parsed_depends = block["depends"]&.split(/\s*,\s*/)  || []
      is_distractor = parsed_depends&.include?("-1") || block["feedback"]
  
      if (is_distractor)
        next
      end
  
      # Case: Sublist fails recursive call or dependency not 
      # found among previous blocks 
      if ((blocklist && deps_violation(blocklist)) ||
          (!(parsed_depends - previous_blocks).empty?))
          return true
      end

      if (blockid && blockid != "fixed" && blockid != "reusable")
          previous_blocks << blockid
      end
    end
  
    return false
  end
end
