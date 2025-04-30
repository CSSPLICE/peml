require 'pp'
require_relative "pif"
require_relative "parser"
require_relative "converter"

examples_path = "#{File.dirname(File.expand_path(__FILE__))}/feasability-examples"
pif_to_parsons_path = "#{File.dirname(File.expand_path(__FILE__))}/pif-to-parsons"
pif_hashes_path = "#{File.dirname(File.expand_path(__FILE__))}/pif-hashes"

Dir.glob('*', base: examples_path).each do |filename|
  puts filename
  content = File.read("#{examples_path}/#{filename}")
  parsed = Parser.parse({pif: content})
  diagnostics = parsed[:diagnostics]; 

  if (diagnostics.length == 0)
    File.open("#{pif_to_parsons_path}/#{filename}.txt", 'w') do |file|
      file.puts(Converter.to_Runestone(parsed[:value], "json"))
    end
  end

  File.open("#{pif_hashes_path}/#{filename}.txt", 'w') do |file|
    PP.pp(parsed, file)
  end
end