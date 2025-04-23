require 'pp'
require_relative "pif"
require_relative "parser"
require_relative "parsons"

examples_path = "#{File.dirname(File.expand_path(__FILE__))}/feasability-examples"
pif_to_parsons_path = "#{File.dirname(File.expand_path(__FILE__))}/pif-to-parsons"

Dir.glob('*', base: examples_path).each do |filename|
  content = File.read("#{examples_path}/#{filename}")
  parsed = Parser.parse({pif: content})
  diagnostics = parsed[:diagnostics]; 

  if (diagnostics.length == 0)
    File.open("#{pif_to_parsons_path}/#{filename}.txt", 'w') do |file|
      PP.pp(Parsons.convert_PIF(parsed[:value]), file)
    end
  end
end