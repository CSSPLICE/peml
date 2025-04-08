module Parsons 
    def self.convert_PIF(pif)
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