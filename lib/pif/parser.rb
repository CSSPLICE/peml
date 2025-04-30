require_relative "../peml"
require 'dottie/ext'
require 'csv'

# Notes to self: 
# 1.) Determine whether both blocklist and blocklist[0] and have 
#     depends fields, and if so, what each represents 
# 2.) Ask if there are two adjacent blocklists, will the second 
#     depend on the first if its dependency array is empty? 

# 2.) If using execution-based grading, does PIF require all of the following: 
#     tabular test content, format, wrapper, and pattern_actual <-- required exactly
#     pattern.actual (compared against expected)
#     So wrapper is not necessary <-- there is a default 
# ISSUES: 
# reduction example was missing a blockid (resultied in a false cycle detection)
# simpledemo-math flagged because uses explicit ordering (any test content should be for execution-based grading)
# pb-induction has dependency on distractor 
# duplicateid in fixed demos (should be random2b3)
# peml parser having trouble corresponding blockids and overwriting display fields

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

    # Parses PIF content as PEML 
    value = Peml::Loader.new.load(pif).dottie!

    # Validates PIF 
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

        # Checks that the required fields for execution-based grading 
        # are included 
        if (style_tag.include?("execute") && (!test_content || !test_format))
          diags << 'Missing required test content and test format'\
                   'fields for execution-based grading.'
        end

        # Separates blocks into normal blocks, blocklists, and distractors 
        # Separated blocks are given an addition "pos" field
        s = separate_blocks(block_content)
        normal_blocks = s[0]
        blocklists = s[1]
        distractors = s[2]

        # Checks for a dependency cycle (currently capable of only 
        # checking blocklist-free problems)
        if (blocklists.empty? && has_cycle(normal_blocks))
          diags << "Dependency cycle detected."
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
    depends = block["depends"]
    feedback = block["feedback"]
    is_distractor = depends == -1 || feedback

    # Case: Normal block 
    if (!blocklist && curr_blockid && !is_distractor)
      return [curr_blockid]
    end

    # Case: Blocklist 
    if (blocklist)
      # Recursively gets blockids of nested elements 
      blockids = curr_blockid ? [curr_blockid] : []
      blocklist.each do |nested_block| 
        blockids += get_blockids_helper(nested_block)
      end
      return blockids 
    end

    # Case: Distractor 
    return []
  end

  # ------------------------------------------------------------------------------
  # Gets all block dependencies for non-distractor elements 
  def self.get_blockdeps(blocks)
    blocks.inject([]) {|depends, block| depends + get_blockdeps_helper(block)}
  end

  # ------------------------------------------------------------------------------
  # Recursive helper for get_blockdeps
  def self.get_blockdeps_helper(block)
    depends = block["depends"]
    feedback = block["feedback"]

    curr_blockdeps = unless !depends || depends == "-1" || feedback
      block["depends"].split(/\s*,\s*/)
    else
      []
    end    
    blocklist = block["blocklist"]

    # Case : Normal block 
    if (!blocklist)
      return curr_blockdeps
    # Case: Blocklist 
    else 
      blockdeps = curr_blockdeps
      # Recursively gets dependencies of all nested elements 
      blocklist.each do |nested_block|
        blockdeps += get_blockdeps_helper(nested_block)
      end
      return blockdeps
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

      if (!curr_deps.all? {|d| blockids.include?(d)})
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
  # Checks whether any blocks form a cycle
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
           &.split(/\s*,\s*/)
           &.map { |d| block_position_lookup[d] } || []

      # Implicit dependency on previous, non-distractor 
      # block 
      if (depends.empty? && i != 0)
        depends = [i - 1] 
      end

      dependencies_lookup[i] = depends
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
end