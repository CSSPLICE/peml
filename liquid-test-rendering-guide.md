# Beginner's Guide to Liquid Test Rendering in PEML

PEML uses [Liquid](https://shopify.github.io/liquid/), a flexible template language, to turn your data-driven test cases into actual code (Java, Python, etc.). While PEML provides "standard" templates for these languages, you can override any part of the process using the `pattern.*` key in your PEML file.

## 1. Common "Pattern" Keys

If you want to customize how your tests are generated, these are the most common keys you will define in your PEML file.

### **pattern.method_call**

This defines how to "call" the code you are testing.

- **Purpose**: Describes the method call and its arguments.
- **Example**: `calculate({{a}}, {{b}}, {{op}})`
- **How it's used**: PEML replaces `{{column_name}}` with values from your data table and places this call inside the test method.

### **pattern.actual**

- **Purpose**: Defines the full expression that represents the result of the code being tested.
- **Example**: `mySolution.calculate({{a}}, {{b}}, {{op}})`
- **How it's used**: This value is compared against your `expected` results. By default, it usually includes `subject.` followed by the `method_invocation`.

### **pattern.method_name**

- **Purpose**: If you only want to change the name of the method being called, without changing how arguments are passed.
- **Example**: `add`
- **How it's used**: Combined with `arguments` to build the default `method_invocation`.

### **pattern.arguments**

- **Purpose**: Defines the comma-separated list of values passed to the method.
- **Example**: `{{a}}, {{b}}, {{op}}`
- **How it's used**: Combined with `method_name` to build the default `method_invocation`.

### **pattern.assertEquals**

- **Purpose**: Defines how the result of your code is compared to the expected value.
- **Example**: `assertEquals({{hint}}, {{expected}}, {{actual`}}`)`
- **How it's used**: This is a building block (usually the only one) in representing the claims inside a test case method. You can override it if you want to change the assertion method or structure of this comparison.

### **pattern.test_case_assertions**

- **Purpose**: Defines the full set of claims generated in each test case method.
- **Example**: `{% assertEquals %}`
- **How it's used**: The default is a single assertEquals() pattern, but you can redefine this to include multiple assertions when needed.

---

## 2. Top-Down Reference

PEML follows a hierarchical structure to build a test file. Each item below corresponds to a template name that you can override.

### **The big picture: `test_class`**

The root template. It assembles everything else.

1. **`stock_imports`**: Standard library imports required by the testing framework.
2. **`extra_imports`**: Any additional imports you want to add.
3. **`class_declaration`**: The line that starts the class (e.g., `public class ...`).
   - Includes **`test_class_name`**: The name of the class.
   - Includes **`test_class_extends`**: Any superclass inheritance.
4. **`extra_declarations`**: Variables or methods shared by all test cases in this file.
5. **`setup`**: Code that runs before *every* test case (e.g., creating a new object).
6. **`test_case` loop**: PEML looks at each row in your data table and runs the **`test_method`** template for it.
7. **`teardown`**: Code that runs after *every* test case.

### **Inside a test case: `test_method`**

This template defines what a single test looks like.

1. **`test_method_annotations`**: Metadata for the test (like `@Test` or `@Example`).
2. **`stdin_setup`**: If your code reads from standard input, this sets up the input stream.
3. **`test_case_actions`**: The part where your code actually runs.
   - Includes **`actual`**: The expression producing the result to be checked.
     - Includes **`method_call`**: The full method call (e.g., `myMethod(a, b)`).
       - Includes **`method_name`**: The name of the method.
       - Includes **`arguments`**: The values passed to the method.
4. **`test_case_assertions`**: Checking the result against the `expected` column.
   - Includes **`assertEquals`**: The specific comparison logic.
5. **`stdout_assertions`**: Checking that any printed output matches what you expected.

---

## 3. Language Agnostic Logic

Although the *contents* of these templates change based on the programming language (Java vs. Python), their **purpose** remains the same:

- **Agnostic Purpose**: "How do I check if two values are equal?"
- **Java Implementation**: `assertEquals(expected, actual);`
- **Python Implementation**: `self.assertEqual(expected, actual)`

By overriding these keys in your PEML `pattern` map, you can tweak the generated code without learning the internal details of every language's template suite.

## 4. Example Override in PEML

```peml
[.assets.test.files]
type: text/x-unquoted-csv
# Here we override common templates
pattern.test_class_name: MyLogicTests
pattern.test_case_assertions: customAssert({{expected}}, {{actual}}, 0.001)
pattern.actual: mySolution.run({{a}}, {{b}})
content:----------
a, b, expected
10, 5, 15
----------
[]
```
