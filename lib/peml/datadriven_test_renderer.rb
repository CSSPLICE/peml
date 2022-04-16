require "dottie/ext"

module Peml
    class DatadrivenTestRenderer

        #This path points to the directory where the liquid templates are saved
        @@template_path = File.expand_path('templates/', __dir__) + "/"

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
            test_structure = {'class_name' => 'Answer'}
            test_cases = []
            id=0
            languages.length.times do |i|
                test_structure['language'] = languages[i]
                template_class = Liquid::Template.parse(File.open(@@template_path+languages[i].downcase+"_class.liquid").read, :error_mode => :strict)
                file_arr.length.times do |j|
                    tests = []
                    test_structure['test_case_count'] = file_arr[j].length
                    file_arr[j].length.times do |k|
                        id=id+1
                        if(value["assets.test.files"]!=nil)
                            method_pattern = value["assets.test.files"][j]["pattern_actual"]
                        elsif(value["systems.[0].suites"]!=nil)
                            method_pattern = value["systems.[0].suites"][j]["template"]
                        end
                        method_name = method_pattern[method_pattern.index('.')+1..method_pattern.index('(')-1]
                        intput = method_pattern[method_pattern.index('(')+1..method_pattern.index(')')-1].gsub(/\{\{(.*?)\}\}/) { |x| file_arr[j][k][x] }
                        expected_output = file_arr[j][k]["expected"]
                        class_name = "Test"
                        negative_feedback= "you should do better"

                        tests.append(TEST_METHOD_TEMPLATES[languages[i]]%{
                            id: id,
                            expected_output: expected_output,
                            method_name: method_name,
                            class_name: class_name,
                            input: intput,
                            negative_feedback: negative_feedback
                })
                        metadata_temp = {'file': j, 'number': k, 'method_name': 'test'+id.to_s, 'example': true, 'hidden': false}  
                        test_cases.push(metadata_temp.merge(file_arr[j][k]))  
                    end
                    test_structure['test_cases'] = test_cases 
                    if(value["assets.test.files"]!=nil)
                        value['assets.test.files'][j]['parsed_tests'] = template_class.render('class_name' => "Answer", 'methods' => tests)
                        value['assets.test.files'][j]['test_structure'] = test_structure
                    elsif(value["systems.[0].suites"]!=nil)
                        value['systems.[0]']['parsed_tests'] = template_class.render('class_name' => "Answer", 'methods' => tests)
                        value['systems.[0]']['test_structure'] = test_structure
                    end 
                end
            end
            return value
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
                temp_arr=[]
                files[i]["cases"].length.times do |j|
                    temp_hash={}
                    files[i]["cases"][j].each do |key, value|
                        if key!="expected" && key!="description"
                            temp_hash["{{"+key+"}}"]=value
                        else
                            temp_hash[key] = value
                        end
                    end
                    temp_arr.append(temp_hash)
                end
                file_arr.push(temp_arr)
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
    public void test%{id}()
    {
        assertEquals(
          "%{negative_feedback}",
          %{expected_output},
          subject.%{method_name}(%{input}));
    }
JAVA_TEST
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
