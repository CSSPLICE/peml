require "dottie/ext"

module Peml
    class Tester

        def generate_tests(peml)
            value=peml.dottie!
            languages = self.get_languages(value)
            file_arr = self.parse_content(value["assets.test.files"])
            languages.length.times do |i|
                file_arr.length.times do |j|
                    file_arr[j].length.times do |k|
                        id = 1
                        method_pattern = value["assets.test.files"][j]["pattern_actual"]
                        method_name = method_pattern[method_pattern.index('.')+1..method_pattern.index('(')-1]
                        intput = method_pattern[method_pattern.index('(')+1..method_pattern.index(')')-1].gsub(/\{\{(.*?)\}\}/) { |x| file_arr[j][k][x] }
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

        def get_languages(value)
            systems = value["systems"]
            languages=[]
            systems.length.times do |i|
                languages.push(systems[i]["language"])
            end
            return languages
        end

        def parse_content(files)
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
