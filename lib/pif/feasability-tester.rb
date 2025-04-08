require_relative "pif"
require_relative "parser"

examples_path = "#{File.dirname(File.expand_path(__FILE__))}/feasability-examples"

Dir.glob('*', base: examples_path).each do |filename|
  content = File.read("#{examples_path}/#{filename}")
  parsed = Parser.parse({pif: content})
  # content_lines = parsed.to_s().scan(/.{1,80}/)

  diagnostics = parsed[:diagnostics]; 
  # # diag_lines = diagnostics.to_s().scan(/.{1,80}/)

  if (diagnostics.length > 0)
    puts "#{filename} contained the following diagnostic messages:"
    puts "\t#{diagnostics}\n\n"
  end
  # puts filename
  # if (parsed[:value]["assets.code.starter.files[0].content"].is_a?(Array))
  #   puts Parser.separate_blocks(parsed[:value]["assets.code.starter.files[0].content"])
  #   puts ""
  # end
end