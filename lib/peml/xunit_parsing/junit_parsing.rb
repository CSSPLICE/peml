require_relative '../xunitparser'

class JUnit_Parser < Peml::XUnit_Parser

    def parse_then(then_statement)
        if then_statement.include?("[]")
            return self.parse_array_equivalence(then_statement)
        elsif then_statement.match(/some_regex/)
            return self.parse_regex(then_statement)
        elsif then_statement.match(/floating_point_pattern/) 
            return self.parse_floating_point(then_statement)
        elsif then_statement.match(/some_message_pattern/)
            return self.parse_messages(then_statement)
        elsif then_statement.include?("=&=")
            then_arr = then_statement.split("=&=")
            return "assertSame(" + then_arr[0]+","+then_arr[1]+")"
        elsif then_statement.include?("!&=")
            then_arr = then_statement.split("!&=")
            return "assertNotSame(" + then_arr[0]+","+then_arr[1]+")"
        else
            return then_statement
        end
    end

    def parse_array_equivalence(then_statement)
        if then_statement.include?("===")
            then_arr = then_statement.split("===")
            return "assertArrayEquals(" + then_arr[0]+","+then_arr[1]+")"
        elsif then_statement.include?("!==")
            then_arr = then_statement.split("!==")
            return "assertArrayNotEquals(" + then_arr[0]+","+then_arr[1]+")"
        end
    end

    def parse_regex(statement)
    end

    def parse_floating_point(statement)
        if then_statement.include?("===")
            then_arr = then_statement.split("===")
            return "assertEquals(" + then_arr[0]+","+then_arr[1]+")"
        elsif then_statement.include?("!==")
            then_arr = then_statement.split("!==")
            return "assertNotEquals(" + then_arr[0]+","+then_arr[1]+")"
        end
    end

    def parse_messages(statement)
    end
end