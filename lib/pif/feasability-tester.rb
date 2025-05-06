require 'pp'
require_relative "parser"
require_relative "converter"

current_dir = File.dirname(File.expand_path(__FILE__))

# Input directories 
error_examples_path = "#{current_dir}/extended-validation-error-examples"
feasability_examples_path = "#{current_dir}/feasability-examples"
input_dirs = [error_examples_path, feasability_examples_path]

# Output directories 
example_hashes_path = "#{current_dir}/example-hashes"
runestone_conversions_path = "#{current_dir}/runestone-conversions"

input_dirs.each do |dir|
  Dir.glob("*", base: dir).each do |filename|
    puts filename
    content = File.read("#{dir}/#{filename}")
    parsed = Parser.parse({pif: content})
    value = parsed[:value].dottie!
    diagnostics = parsed[:diagnostics]; 

    has_nontrivial_blocklist= value["assets.code.blocks.content"]
        &.any? {|block| block["blocklist"] && !block["pickone"]}

    if (diagnostics.length == 0 && !has_nontrivial_blocklist)
      File.open("#{runestone_conversions_path}/#{filename}.txt", 'w') do |file|
        file.puts(Converter.to_Runestone(parsed[:value], "json"))
      end
    end

    File.open("#{example_hashes_path}/#{filename}.txt", 'w') do |file|
      PP.pp(parsed, file)
    end
  end
end