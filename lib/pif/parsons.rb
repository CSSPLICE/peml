module Parsons 
    # Still need to add a field for test (one added to spec)
    # Assumes an already validated and parsed PIF hash is passed
    def self.convert_PIF(pif)
        tags = pif['tags']
        blocks = pif['assets.code.blocks.content']
  
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

        diags = []
        # Validates that the language specified is supported 
        language = pif["systems[0].language"]
        supported_languages = ["python", "java", "javascript", "html", "c", "c++", "ruby", "natural"]
        if !supported_languages.include?(language)
          diags << "#{language} is not a supported langauge"
        end
  
        # Converts each PIF block into a Parsons block 
        blocks.each do |block|
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
          # Case: Normal block 
          else
            parsons_block["text"] = block["display"]
  
            if block["depends"] == -1 
              parsons_block["type"] = "distractor"
            else 
              parsons_block["tag"] = block["blockid"] || ""
              parsons_block["depends"] = block["depends"] || ""
            end 
  
            parsons_data_model["blocks"] << parsons_block
          end 
        end
        parsons_data_model
    end