require_relative "../peml"
require 'dottie/ext'
require 'csv'

require "kramdown"
require 'kramdown-parser-gfm'
require 'kramdown-math-katex'

module PifParser
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
        delimiter = value['assets.code.blocks.delimiter'] || "`" # Optional
        test_content = value['assets.test.files[0].content'] # Optional
        test_format = value['assets.test.files[0].format'] # Optional
        systems = value['systems'] # Optional

        # Style tag indicators (case-sensitive)
        parsed_style_tag = style_tag.split(/\s*,\s*/)
        has_parsons_tag = parsed_style_tag.include?("parsons")
        has_execute_tag = parsed_style_tag.include?("execute")
        has_order_tag = parsed_style_tag.include?("order")
        has_indent_tag = parsed_style_tag.include?("indent")

        # Checks that style tag contains "parsons" AND
        # EITHER "order" or "execute" (in no specific order)
        if (!has_parsons_tag ||
          !(has_execute_tag ||
            has_order_tag) ||
          (has_execute_tag && has_order_tag)
        )
          diags << "Style tag requires 'parsons' and either 'order' or 'execute' keywords."
        end

        # Checks that the required fields for execution-based grading
        # are included
        if (has_execute_tag && (!test_content || !test_format || !systems))
          diags << "Missing required test content, test format, or language " \
            "fields for execution-based grading."
        end

        # Separates blocks into normal blocks, blocklists, and distractors
        # Separated blocks are given an addition "pos" field
        s = separate_blocks(block_content)
        normal_blocks = s[0]
        blocklists = s[1]
        distractors = s[2]

        if (deps_violation(block_content))
          diags << "Dependencies must refer to previously defined blocks " \
            "within the same blocklist scope."
        end

        if (picklimit_violation(blocklists))
          diags << "Invalid pick limit, pick limit must be a positive int " \
            "less than the number of blocks"
        end

        # Checks if indentation is required and, if so,
        # whether all normal blocks have an indent level
        if (has_indent_tag &&
          has_order_tag)
          normal_blocks.each do |block|
            indent = block["indent"]
            pos = block["pos"]

            if indent.nil?
              diags << "Block at position #{pos} is missing the required " \
                "indent field."
            end

          end
        end

        # If indent style keyword is not used,
        # then checks that no block contains an indent level.
        if (!has_indent_tag)
          # Could recursively process block_content -
          # but previous operation has already separated
          # them into easily workable form

          catch(:illegal_indent) do
            s.each do |block_group|
              block_group.each do |block|
                indent = block["indent"]

                if !indent.nil?
                  diags << "Block(s) contain indent fields despite missing 'indent' style keyword."
                  throw :illegal_indent
                end
              end
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

        get_toggles_and_text_input(block_content, delimiter)

        # Checks that the CSV test content is correctly formatted,
        # i.e., the header length matches all row lengths
        if (has_execute_tag && test_content)
          parsed_test_content = Peml::CsvUnquotedParser.new.parse(
            test_content
          )
          header = parsed_test_content[0]

          parsed_test_content[1..].each_with_index do |row, i|
            if (row.length != header.length)
              diags << "Row #{i} of the test content does not match " \
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
  # Gets all toggle options and text inputs for blocks
  def self.get_toggles_and_text_input(blocks, delimiter)
    blocks.each do |block|
      self.get_toggles_and_text_input_helper(block, delimiter)
    end
  end

  # ------------------------------------------------------------------------------
  # Recursive helper for get_toggles
  def self.get_toggles_and_text_input_helper(block, delimiter)
    blocklist = block["blocklist"]
    if(blocklist)
      blocklist.each do |child|
        get_toggles_and_text_input_helper(child, delimiter)
        return
      end
    end

    text_options = get_text_input(block, delimiter)
    toggle_options = get_toggles(block, delimiter)

    if(text_options || toggle_options)
      block["text_toggle_options"] = []
      block["text_toggle_options"].concat(text_options)
      block["text_toggle_options"].concat(toggle_options)
    end

    puts block["text_toggle_options"]
  end
  
  # ------------------------------------------------------------------------------
  # Searches for toggle options within 2 delimiter groups
  def self.get_toggles(block, delimiter)
    toggles = []
    # Scans for groups of 2 or greater delimiters
    toggleMatches = block["display"].split(/#{Regexp.escape(delimiter)}{2}/)

    endOfDelimiterGroup = 0
    toggleMatches.each_with_index do |str, index| # Loop through each toggle match
      next if index.even? # skip text outside of toggle group delimiters

      #Search from end of last delimiter group or start of string
      startOfDelimiterGroup = block["display"].index(/#{Regexp.escape(delimiter)}{2}/, endOfDelimiterGroup) 
      endOfDelimiterGroup = block["display"].index(/#{Regexp.escape(delimiter)}{2}/, startOfDelimiterGroup + 2) + 2 #Search for ending delimiter from end of starting delimiter

      toggle_options = str.split(delimiter) #All toggle options within toggle group
      toggles << {start_index: startOfDelimiterGroup, end_index: endOfDelimiterGroup, values: toggle_options, type: "toggle"}
    end

    return toggles
  end

  # ------------------------------------------------------------------------------
  # Searches for groups of 4 delimiter
  def self.get_text_input(block, delimiter)
    text_inputs = []
    match_end = 0 # Variable to store the index after the last matched group
    while match = block["display"].index(/#{Regexp.escape(delimiter)}{4}/, match_end)
      match_end = match + 4
      text_inputs << {start_index: match, end_index: match_end, type: "text"}
    end
    return text_inputs
  end

  # ------------------------------------------------------------------------------
  # Gets all blockids for non-distractor elements
  def self.get_blockids(blocks)
    blocks.inject([]) { |ids, block| ids + get_blockids_helper(block) }
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
    else
      (blocklist)
      return Array(curr_blockid)
    end
  end

  # ------------------------------------------------------------------------------
  # Gets all block dependencies for non-distractor elements
  def self.get_blockdeps(blocks)
    blocks.inject([]) { |depends, block| depends + get_blockdeps_helper(block) }
  end

  # ------------------------------------------------------------------------------
  # Recursive helper for get_blockdeps
  def self.get_blockdeps_helper(block)
    parsed_depends = block["depends"]&.split(/\s*,\s*/) || []
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

    blocks.inject([[], [], []]) do |res, block|
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

    block = block.merge({ "pos" => pos })

    # Case: Blocklist
    if (blocklist)
      blocklists << block

      # Recursively separates nested blocks and merges results
      blocklist.each_with_index do |nested_block, i|
        x, y, z = separate_blocks_helper("#{pos}.#{i + 1}", nested_block)
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
      parsed_depends = block["depends"]&.split(/\s*,\s*/) || []
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

  def self.markdown_renderer(hash)

    # puts "instructions: #{hash["instructions"]}"
    instruction_text = PifParser.identify_inline_delimiters(hash["instructions"])
    hash["instructions"] = Peml::Utils.render_helper(
      instruction_text,
      math_engine: :katex,
      math_engine_options: { output: 'mathml' }
    )
    # puts "new instructions: #{hash["instructions"]}"

    if hash.has_key?("systems")
      language = hash["systems"]&.first&.[]("language")
      is_git_flavored_markdown = ["math", "natural"].include?(language&.downcase)
    else
      is_git_flavored_markdown = true
    end

    # puts "is_git_flavored_markdown: #{is_git_flavored_markdown}"

    if is_git_flavored_markdown
      # puts hash["assets"]["code"]["blocks"]["content"]
      hash["assets"]["code"]["blocks"]["content"].each do |block|
        # puts "block: #{block["display"]}"
        if block["blocklist"] && !block["blocklist"].empty?
          block["blocklist"].each do |sub_block|
            display_text = PifParser.identify_inline_delimiters(sub_block["display"])
            parsed_to_html = Kramdown::Document.new(
              display_text,
              :auto_ids => false,
              input: 'GFM',
              math_engine: "katex"
            ).to_html

            sub_block["display"] = PifParser.strip_tags_and_convert_to_latex(parsed_to_html)
          end

        else
          display_text = PifParser.identify_inline_delimiters(block["display"])
          parsed_to_html = Kramdown::Document.new(
            display_text,
            :auto_ids => false,
            input: 'GFM',
            math_engine: "katex"
          ).to_html

          block["display"] = PifParser.strip_tags_and_convert_to_latex(parsed_to_html)
        end

        # puts "new block: #{block["display"]}"

      end
    end

    hash

  end

  private

  # Not the cleanest way to do this, but it works.
  def self.strip_tags_and_convert_to_latex(html)
    # Remove wrapping <p> and </p> tags
    html = html.strip.sub(/\A<p[^>]*>/i, '').sub(/<\/p>\z/i, '')

    # HTML tag to LaTeX replacements
    replacements = {
      /<b>(.*?)<\/b>/i => '$\\textbf{\1}$',
      /<strong>(.*?)<\/strong>/i => '$\\textbf{\1}$',
      /<i>(.*?)<\/i>/i => '$\\textit{\1}$',
      /<em>(.*?)<\/em>/i => '$\\textit{\1}$',
      /<u>(.*?)<\/u>/i => '$\\underline{\1}$',
      /<br\s*\/?>/i => " $\\\\$",
      /<sup>(.*?)<\/sup>/i => '$^{\1}$',
      /<sub>(.*?)<\/sub>/i => '$_{\1}$',
    }

    replacements.each do |regex, replacement|
      html = html.gsub(regex, replacement)
    end

    html
  end

  def self.identify_inline_delimiters(html)
    # Remove wrapping <p> and </p> tags
    html = html.strip.sub(/\A<p[^>]*>/i, '').sub(/<\/p>\z/i, '')

    # HTML tag to LaTeX replacements
    replacements = {
      /\\\((.*?)\\\)/i => '$\1$',
      /\\\[(.*?)\\\]/i => '$$\1$$',
    }

    replacements.each do |regex, replacement|
      html = html.gsub(regex, replacement)
    end

    html
  end

  def self.picklimit_violation(blocklists)
    blocklists.each_with_index do |blocklist|
      picklimit = 0
      begin
        picklimit = blocklist["picklimit"].to_i
      rescue StandardError
        return true;
      end

      if (picklimit < 0 || \
        picklimit > blocklist["blocklist"].length)
        return true
      end
    end

    return false
  end
end