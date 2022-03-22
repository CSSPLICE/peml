require "dottie/ext"
require "liquid"

module Peml
    class Tester

        #This function parses tests written in the PEML Test
        #dsl. Each of the blocks are collected into a hash and
        #then sent ahead to make a class/test methods out of
        def generate_tests_from_dsl(peml)
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
            self.get_tests_from_template(test_hash)
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
        def get_tests_from_template(test_hash)
            methods=[]
            java_method = Liquid::Template.parse(File.open("/peml/test/templates/java_function.liquid").read, :error_mode => :strict)
            java_class = Liquid::Template.parse(File.open("/peml/test/templates/java_class.liquid").read, :error_mode => :strict)
            test_hash["thens"].length.times do |i|
                methods.push(java_method.render('id' => i, 'givens' => test_hash["givens"], 
                    'whens' => test_hash["whens"], 'then' => self.parse_then(test_hash["thens"][i])))
            end
            puts(java_class.render('class_name' => test_hash["class_name"],'imports' => test_hash["imports"], 'methods' => methods))
        end

        #only basic assert equals parsing for now, more
        #features will be added to this function, need work
        #with handling expressions that are not assert type
        def parse_then(then_statement)
            if then_statement.include?("===")
                then_arr = then_statement.split("===")
                return "assertEquals(" + then_arr[0]+","+then_arr[1]+");"+"\n"
            else
                return then_statement
            end
            
        end

        #This function has been designed for parsing test cases presented in 
        #tabular format to individual testable x-unti style methods. Needs 
        #better refracotring. 
        def generate_tests(peml)
            value=peml.dottie!
            languages = self.get_languages(value)
            if(value["assets.test.files"]!=nil)
                file_arr = self.parse_csv(value["assets.test.files"])
            elsif(value["systems.[0].suites"]!=nil)
                file_arr = self.parse_hash(value["systems.[0].suites"])
            end
            id=0
            languages.length.times do |i|
                file_arr.length.times do |j|
                    file_arr[j].length.times do |k|
                        id=id+1
                        if(value["assets.test.files"]!=nil)
                            method_pattern = value["assets.test.files"][j]["pattern_actual"]
                            method_name = method_pattern[method_pattern.index('.')+1..method_pattern.index('(')-1]
                            intput = method_pattern[method_pattern.index('(')+1..method_pattern.index(')')-1].gsub(/\{\{(.*?)\}\}/) { |x| file_arr[j][k][x] }
                        elsif(value["systems.[0].suites"]!=nil)
                            method_pattern = value["systems.[0].suites"][j]["template"]
                            method_name = method_pattern[method_pattern.index('.')+1..method_pattern.index('(')-1]
                            intput = method_pattern[method_pattern.index('(')+1..method_pattern.index(')')-1].gsub(/\{\{(.*?)\}\}/) { |x| file_arr[j][k][x] }
                        end
                        expected_output = file_arr[j][k]["expected"]
                        class_name = "Test"
                        negative_feedback= "you should do better"

                        puts(TEST_METHOD_TEMPLATES[languages[i]]%{
                            id: id,
                            expected_output: expected_output,
                            method_name: method_name,
                            class_name: class_name,
                            input: intput,
                            negative_feedback: negative_feedback
                })
                    end
                end
            end
            return peml
        end

        #Gets list of language we need test cases for. Only used
        #by test cases with tabular data for now.
        def get_languages(value)
            systems = value["systems"]
            languages=[]
            systems.length.times do |i|
                languages.push(systems[i]["language"])
            end
            return languages
        end

        #Parses the suites array into an array of hashes
        def parse_hash(files)
            file_arr=[]
            files.length.times do |i|
                file_arr.push(files[i]["cases"])
            end
            return file_arr
        end

        #Parses CSV tabular data into an array of hashes to make
        #the two testing format similar.
        def parse_csv(files)
            file_arr = []
            files.length.times do |i|
                content_lines = files[i]["content"].split("\n")
                header = content_lines[0].split(",")
                content_arr = []
                (1..content_lines.length-1).each do |j|
                    content_row = content_lines[j].split(",")
                    content_hash_entry = {}
                    content_row.length.times do |k|
                        if header[k]!="expected" && header[k]!="description"
                            content_hash_entry["{{"+header[k]+"}}"] = content_row[k]
                        else
                            content_hash_entry[header[k]] = content_row[k]
                        end  
                    end
                    content_arr.push(content_hash_entry)
                end
                file_arr.push(content_arr)
            end
            return file_arr
        end
    end

    #List of templates that have been utilized for generating tests.
    TEST_METHOD_TEMPLATES = {
      'Ruby' => <<RUBY_TEST,
  def test%{id}
    assert_equal(%{expected_output}, @@subject.%{method_name}(%{input}), "%{negative_feedback}")
  end
RUBY_TEST
      'Python' => <<PYTHON_TEST,
    def test%{id}(self):
        self.assertEqual(%{expected_output}, self.__%{method_name}(%{input}))
PYTHON_TEST
      'Java' => <<JAVA_TEST,
    @Test
    public void test_%{id}()
    {
        assertEquals(
          "%{negative_feedback}",
          %{expected_output},
          subject.%{method_name}(%{input}));
    }
JAVA_TEST
      'JavaMethod' => <<JAVA_TEST_METHOD,
    @Test
    public void test_%{id}()
    {
        %{givenStr}
        %{whenStr}
        %{thenStr}
    }
JAVA_TEST_METHOD
      'JavaClass' => <<JAVA_TEST_CLASS,
    class %{class_name}
    {
        %{importStr}
        %{test_methods}
    } 
JAVA_TEST_CLASS
      'C++' => <<CPP_TEST
    void test%{id}()
    {
        TSM_ASSERT_EQUALS(
          "%{negative_feedback}",
          %{expected_output},
          subject.%{method_name}(%{input}));
    }
CPP_TEST
    }
end
