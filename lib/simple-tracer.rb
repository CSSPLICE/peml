require 'term/ansicolor'

class String
  include Term::ANSIColor
end

module Tracer
  depth = 0
  space = "| ".magenta
	filters = []

	set_trace_func proc { |event, file, line, id, binding, classname, *rest|
		if file != __FILE__
			if 'Peml::Loader' == classname.to_s

				case event
				when "call"
					# puts "CALL"
					arg_names = eval("method(__method__).parameters.map { |arg| arg[1].to_s }",binding)
					args = eval("#{arg_names}.map { |arg| eval(arg).inspect }", binding).join(', ')
					puts space * (depth * 2) + "====> ".green.bold + classname.to_s + "." + id.to_s.bold + "(#{args})"
					puts space * (depth * 2) + "    > " + "#{file.split('/').last}:#{line}".blue + "  args: (#{arg_names.join(', ')})".blue
					depth += 1
				when "return"
					# puts "RET"
					depth -= 1 if depth > 0
					puts space * (depth * 2) + "<==== ".red.bold + classname.to_s + "."	+ id.to_s.bold
				end
			end
		end
	}

end
