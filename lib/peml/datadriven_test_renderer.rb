
require_relative 'csv_unquoted_parser'
require 'dottie/ext'
require 'csv'

module Peml
    class DatadrivenTestRenderer

        #This path points to the directory where the liquid templates are saved
        @@template_path = File.expand_path('templates/', __dir__) + "/"

        # This is the entry function for data-driven test generation
        # We fetch languages and then generate tests for each using 
        # the helper function written below.
        def generate_tests(peml)
            value = peml.dottie!
            languages = self.get_languages(value)
            tests = self.recurse_hash(value, {})
            if(tests[:format].include?('csv'))
                peml['parsed_tests']=[]
                tests[:content] = hashify_test(tests)
                languages.each do |language|
                    template_class = Liquid::Template.parse(File.open("#{@@template_path}#{language.downcase}_class.liquid").read, :error_mode => :strict)
                    peml['parsed_tests']<<{language: language, test_class: template_class.render('class_name' => 'Answer', 'methods' => generate_methods(tests, language))}
                end
            else
                peml['parsed_tests'] = tests[:content]
            end
            peml
        end

        # Gets list of language we need test cases for. Only used
        # by test cases with tabular data for now.
        def get_languages(value)
            languages=[]
            value['systems'].each do |system|
                languages<<system['language']
            end
            languages
        end

        # Converts the csv file parsed by the csv unquoted parser into 
        # a hash of test cases example header => test_variable
        def hashify_test(tests)
            content_arr=[]
            if(tests[:format].include?('text/csv-unquoted'))
                tests[:content] = Peml::CsvUnquotedParser.new.parse(tests[:content])
            else
                tests[:content] = CSV.new(tests[:content]).read
            end
            (1..tests[:content].length-2).each do |i|
                test_hash = Hash[tests[:content][0].map(&:to_sym).zip(tests[:content][i])]
                content_arr<<test_hash
            end
            content_arr
        end

        # A recursiive walker that walks through the hash and returns files
        # that will most likely have testcases in them (idenitified by form
        # and content keys)
        def recurse_hash(peml, test_hash)
            peml.each do |key, value|
                if value.is_a?(Hash)
                    if value.key?('content') && value.key?('format')
                        test_hash = {content: value['content'], format: value['format'], pattern: value.key?('pattern_actual')?value['pattern_actual']: nil}
                    else
                        test_hash = recurse_hash(value, test_hash)
                    end
                elsif value.is_a?(Array)
                    value.each do |element|
                        if element.key?('content') && element.key?('format')
                            test_hash = {content: element['content'], format: element['format'], pattern: element.key?('pattern_actual')?element['pattern_actual']: nil}
                        else
                            test_hash = recurse_hash(element, test_hash)
                        end
                    end
                end
            end
            test_hash
        end

        # This function returns an array of test functions which are then
        # interpolated into a class before being written into the peml hash
        def generate_methods(tests, language)
            tests_arr=[]
            id=0
            method_name = tests[:pattern][tests[:pattern].index('.')+1..tests[:pattern].index('(')-1]
            tests[:content].each do |test_case|
                id+=1
                intput = tests[:pattern][tests[:pattern].index('(')+1..tests[:pattern].index(')')-1].gsub(/\{\{(.*?)\}\}/) { |x|  test_case[x[2..-3].to_sym]  }
                expected_output = test_case[:expected]
                class_name = "Test"
                negative_feedback= 'you should do better'
                tests_arr<<(TEST_METHOD_TEMPLATES[language]%{
                        id: id,
                        expected_output: expected_output,
                        method_name: method_name,
                        class_name: class_name,
                        input: intput,
                        negative_feedback: negative_feedback
                })
            end
            tests_arr
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

