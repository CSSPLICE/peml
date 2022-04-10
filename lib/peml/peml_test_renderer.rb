require "liquid"

require 'xunit_parsing/ctest_parsing'
require 'xunit_parsing/junit_parsing'
require 'xunit_parsing/minitest_parsing'
require 'xunit_parsing/pyunit_parsing'

module Peml
    class PemlTestRenderer

        #This path points to the directory where the liquid templates are saved
        @@template_path = File.expand_path('templates/', __dir__) + "/"

        #This variable is used to pick the xunit parser based on the language
        @xunit_parser

        #~ Public instance methods .................................................
        def initialize(language)
            case language
            when 'java'
                @xunit_parser = JUnit_Parser.new()
            when 'cpp'
                @xunit_parser = CTest_Parser.new()
            when 'python'
                @xunit_parser = PyUnit_Parser.new()
            when 'ruby'
                @xunit_parser = MiniTest_Parser.new()
        end

        #This function parses tests written in the PEML Test
        #dsl. Each of the blocks are collected into a hash and
        #then sent ahead to make a class/test methods out of
        def generate_tests_from_dsl(peml, language)
            xunit_parser = self.pick_parser(language)
            test_hash={}
            test_hash["class_name"]=peml[:id]
            if(peml.key?(:imports))
                test_hash["imports"] = self.get_statements(:imports, peml)
            end
            if(peml.key?(:givens))
                test_hash["givens"] = self.get_statements(:givens, peml)
            end
            if(peml.key?(:whens))
                test_hash["whens"] = self.get_statements(:whens, peml)
            end
            if(peml.key?(:thens))
                test_hash["thens"] = self.get_statements(:thens, peml)
            end
            self.get_tests_from_template(test_hash, language)
            return peml
        end

        #This function is designed to accept block level arrays like
        #thens, whens, givens, imports etc and pass them to the recursive 
        #walker to return an array of statements with each entry 
        #corresponding to one line of code or one nested expression.
        def get_statements(key, peml)
            arr=[]
            peml[key].length.times do |i|
                arr.push(self.recurse_hash_to_string(peml[key][i], ""))
            end
            return arr
        end

        #This function is a basic recursive walker that recurses through 
        #individual hashes, through sub-hashes and arrays, all the way
        #to the low level string/text values and concatenates them into
        #one line of code or one nested expression.
        def recurse_hash_to_string(hash, str)
            hash.each do |key, value|
                if(value.is_a?(Hash))
                    str=recurse_hash_to_string(value, str)
                elsif(value.is_a?(Array) && value.length>0)
                    value.length.times do |i|
                        str=recurse_hash_to_string(value[i], str)
                    end
                elsif(value.is_a?(String) || value==nil)
                    str += value != nil ? value : ""
                end
            end
            return str
        end

        #Once the final hash is ready, we send it to this function 
        #for templating. We first template the functions using givens,
        #whens and thens and then we template the class using class 
        #name, imports and each of the methods.
        def get_tests_from_template(test_hash, language)
            methods=[]
            template_method = Liquid::Template.parse(File.open(@@template_path+language+"_function.liquid").read, :error_mode => :strict)
            template_class = Liquid::Template.parse(File.open(@@template_path+language+"_class.liquid").read, :error_mode => :strict)
            test_hash["thens"].length.times do |i|
                methods.push(template_method.render('id' => i, 'givens' => test_hash["givens"], 
                    'whens' => test_hash["whens"], 'then' => @xunit_parser.parse_then(test_hash["thens"][i])))
            end
            puts(template_class.render('class_name' => test_hash["class_name"],'imports' => test_hash["imports"], 'methods' => methods))
        end
    end
end
