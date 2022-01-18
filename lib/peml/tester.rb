require "dottie/ext"

module Peml
    class Tester

        #~ Constants ...............................................................
        JAVA_TEST = "@Test
                    public void test_%{id}()
                    {
                        assertEquals(
                        "%{negative_feedback}",
                        %{expected_output},
                        subject.%{method_name}(%{input}));
                    }"

        RUBY_TEST = "def test%{id}
                        assert_equal(%{expected_output}, @@subject.%{method_name}(%{input}), "%{negative_feedback}")
                    end"
        PYTHON_TEST = "def test%{id}(self):
                            self.assertEqual(%{expected_output}, self.__%{method_name}(%{input}))"

        #~..........................................................................

        def generate_tests(peml)
            value=peml.dottie!
            puts(value["assets.code.starter.files.[0].content"])
            puts(value["assets.test.files.[0]"])
            return peml
        end
    end
end
