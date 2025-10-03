require "json"
require "yaml"

module PifConverter
  # Assumes an already validated and parsed PIF hash is passed
  # - specifically the :value field.
  def self.to_runestone(pif, format = nil)
    # PIF-to-Parsons directly mappable data
    tags = pif['tags']
    style = tags['style']
    blocks = pif['assets.code.blocks.content']
    instructions = pif['instructions']
    grader = style.include?('execute') ?
               'exec' :
               'dag'
    indent = style.include?('indent')
    numbered = pif['numbered'] || false
    language = pif['systems[0].language']&.downcase || 'math'

    # Parsons model
    parsons_data_model = {
      "question_text" => instructions,
      "options" => {
        "grader" => {
          "type" => grader,
          "showFeedback" => true,
        },
        "maxdist" => 0,
        "order" => "",
        "indent" => indent,
        "adaptive" => true,
        "numbered" => numbered,
        "language" => language,
        "runnable" => false,
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
        "displaymath" => true,
        "feedback" => "",
        "pickOneBlockCount" => 0
      }.dottie!

      has_blocklist = block["blocklist"]

      # Parsons cannot support nontrivial blocklists
      if has_blocklist && !block["pickone"]
        diags << "Parsons does not support nontrivial blocklists: #{block}."
        # Case: Pickone blocklist
      elsif
        # Adds the root of the blocklist
      parsons_block["text"] = block["blocklist[0].display"]
        parsons_block["pickOneBlockCount"] = block["blocklist"].length;
        parsons_block["tag"] = block["blocklist[0].blockid"] || ""
        parsons_block["depends"] = block["depends"] || ""
        parsons_data_model["blocks"] << parsons_block

        # Adds the closest distractor
        if (block["blocklist"].length > 1)
          distractor = block["blocklist[1]"]
          parsons_distractor = {
            "text" => distractor["display"],
            "tag" => "paired",
            "depends" => "",
            "displaymath" => "",
          }
          parsons_data_model["blocks"] << parsons_distractor
        end
        # Case: Single Block Entity
      else
        parsons_block["text"] = block["display"]

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

        # Appends converted block
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
