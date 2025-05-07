require "json"
require "yaml"

module Converter
    # Assumes an already validated and parsed PIF hash is passed 
    # - specifically the :value field.
    def self.to_Runestone(pif, format=nil)
      # PIF-to-Parsons directly mappable data
      tags = pif['tags']
      style = tags['style']
      blocks = pif['assets.code.blocks.content']
      instructions = pif['instructions']
      grader = style.include?('execute') ? 
        'exec' : 
        'dag'
      noindent = !style.include?('indent')
      numbered = pif['numbered'] || false 
      language = pif['systems[0].language']&.downcase || ''

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
          "noindent" => noindent,
          "adaptive" => true, 
          "numbered" => numbered, 
          "language" => language,
          "runnable" => true, 
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
          "displaymath" => true,
        }.dottie!

        has_blocklist = block["blocklist"]

        # Parsons cannot support nontrivial blocklists 
        if has_blocklist && !block["pickone"]
          diags << "Parsons does not support nontrivial blocklists: #{block}."
        # Case: Pickone blocklist
        elsif 
          # Adds the root of the blocklist 
          parsons_block["text"] = block["blocklist[0].display"]
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
          else 
          # Case: Normal Block 
            parsons_block["tag"] = block["blockid"] || ""
            parsons_block["depends"] = block["depends"] || ""
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