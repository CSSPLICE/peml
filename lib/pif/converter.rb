require "json"
require "yaml"

module PifConverter
  # Assumes an already validated and parsed PIF hash is passed
  # - specifically the :value field.
  def self.to_renderable_json(pif, format = nil)
    # puts "raw pif parse: #{pif['systems[0].assets.code.blocks.content']}"
    # PIF-to-Parsons directly mappable data
    settings        = pif['settings']
    grader_type     = settings['grader']['type']
    indent_settings = settings['indent']
    blocks          = pif['systems[0].assets.code.blocks.content']
    starter         = pif['systems[0].assets.code.starter.files']
    instructions    = pif['instructions']
    grader          = grader_type == 'execute' ? 'exec' : 'dag'
    indent_active   = indent_settings && indent_settings['active'] == 'true'
    indent_options  = {
      "active"      => indent_active,
      "mode"        => indent_settings&.[]('mode') || '',
      "max_indents" => (indent_settings&.[]('max_indents') || '3').to_i,
    }
    show_feedback = settings['grader']['show_feedback'] != 'false'
    numbered      = settings['numbered'] == 'true'
    adaptive      = settings['adaptive'] != 'false'
    delimiter     = pif['systems[0].assets.code.blocks.delimiter'] || '`'
    language      = pif['systems[0].language']&.downcase || 'math'
    displaymath   = ["math", "natural", nil].include?(pif['systems[0].language']&.downcase)

    # Parsons model
    parsons_data_model = {
      "question_text" => instructions,
      "options" => {
        "grader" => {
          "type"          => grader,
          "show_feedback" => show_feedback,
        },
        "indent"   => indent_options,
        "adaptive" => adaptive,
        "numbered" => numbered,
        "language" => language,
      },
      "blocks" => [],
    }.dottie!

    diags = []
    # Checks that the language specified is supported
    supported_languages = [
      "python",
      "java",
      "javascript",
      "html",
      "c",
      "c++",
      "ruby",
      "natural"
    ]
    if grader == "exec" &&
       !supported_languages.include?(language)
      diags << "#{language} is not a supported langauge."
    end

    # Converts each PIF block into a Parsons block
    blocks.each_with_index do |block, i|
      block = block.dottie!

      parsons_block = {
        "text" => "",
        "type" => "",
        "tag" => "",
        "depends" => "",
        "indent" => 0,
        "displaymath" => displaymath,
        "feedback" => "",
      }.dottie!

      has_blocklist = block["blocklist"]

      # Parsons cannot support nontrivial blocklists
      if has_blocklist && !block["pickone"]
        diags << "Parsons does not support nontrivial blocklists: #{block}."
        # Case: Pickone blocklist
      elsif
        # Adds the root of the blocklist
        parsons_block["text"] = block["blocklist[0].display"]
        parsons_block["picklimit"] = block["picklimit"].to_i || 0
        parsons_block["tag"] = "#{block["blockid"]}-#{block["blocklist[0].blockid"]}"
        parsons_block["depends"] = block["depends"] || ""
        if block["reusable"]
          parsons_block["reusable"] = block["reusable"].to_s.strip.downcase == "true"
        end
        parsons_data_model["blocks"] << parsons_block

        # adds a picklimit number of distractors to the data model
        grouped_distractors = block["blocklist"].drop(1)
        puts "blocklist: #{block["blocklist"]}"
        puts "grouped distractors: #{grouped_distractors}"
        puts "picklimit: #{block["picklimit"]}"
        selected_distractors =
            block["picklimit"] ?
            grouped_distractors.sample(block["picklimit"].to_i) :
            grouped_distractors
        selected_distractors.each do |distractor|
          parsons_data_model["blocks"] << {
            "text" => distractor["display"],
            "tag" => "#{block["blockid"]}-#{distractor["blockid"]}",
            "depends" => "-1",
            "displaymath" => displaymath,
            "feedback" => distractor["feedback"],
            "reusable" => block["reusable"].to_s.strip.downcase == "true",
          }
        end
      else
        parsons_block["text"] = block["display"]
        if(block["toggle_options"])
          parsons_block["toggle_options"] = block["toggle_options"]
        end
        if(block["text_options"])
          parsons_block["text_options"] = block["text_options"]
        end

        # Case: Distractor
        if block["depends"] == -1 ||
           block["feedback"]
          parsons_block["type"] = "distractor"
          parsons_block["feedback"] = block["feedback"]
        else
          # Case: Normal Block
          parsons_block["tag"] = block["blockid"] || ""
          parsons_block["depends"] = block["depends"] || ""
          parsons_block["indent"] = block["indent"] || ""
        end

        if block["reusable"]
          parsons_block["reusable"] = block["reusable"].to_s.strip.downcase == "true"
        end

        # pass prescribed indent levels per block; for free mode just signal indentability
        if indent_active
          if indent_settings['mode'] == 'prescribed'
            parsons_block["indent"] = block["indent"]&.to_i || 0
          else
            parsons_block["indent"] = true
          end
        end

        # Appends converted block
        parsons_data_model["blocks"] << parsons_block
      end
    end

    if starter
      starterLines = starter[0]["content"].split("___")
      starterLines.each do |starterLine|
        starterLine = starterLine.strip()

        parsons_block = {
          "text" => "",
          "type" => "",
          "toggle_options" => [],
          "text_options" => [],
          "tag" => "",
          "depends" => "",
          "indent" => "",
          "displaymath" => displaymath,
          "feedback" => "",
        }.dottie!

        parsons_block["text"] = starterLine
        parsons_block["tag"] = "fixed"
        parsons_data_model["blocks"] << parsons_block
      end
    end

    result = {
      "value" => parsons_data_model,
      "diags" => diags
    }

    if (format)
      case format
      when "json"
        result = JSON.pretty_generate(result)
      when "yaml"
        result = result.to_yaml
      end
    end

    return result
  end
end
