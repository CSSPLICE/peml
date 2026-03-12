# Beginner's Guide to Data-Driven Testing in PEML

Data-driven testing allows you to define a set of test cases as a table of data rather than writing individual test scripts for every scenario. PEML takes this data and automatically generates the corresponding code in your target language (Java, Python, C++, etc.).

## 1. The Basics

Data-driven tests live in the `[.assets.test.files]` section of your PEML file. At a minimum, you need three things:

1. **Type**: The format of your data (e.g., `text/x-unquoted-csv`).
2. **Pattern**: A template for how to call your code.
3. **Content**: The table of data itself.

### Simple Example (Unquoted CSV)

This example shows a test for a `calculate` method that takes two integers and a string describing the operation.

```peml
[.assets.test.files]
type: text/x-unquoted-csv
pattern.method_call: calculate({{a}}, {{b}}, {{op}})
content:----------
a, b, op, expected
5, 10, "add", 15
20, 4, "divide", 5
-1, 1, "add", 0
----------
[]
```

---

## 2. Choosing Your Format

PEML supports several ways to write your data tables. Here they are in order of flexibility and readability.

### **Unquoted CSV**

The easiest format for simple numbers and text without needing quotes. Think of it like CSV, but where you can write regular programming literals or expressions without needing to worry about CSV-style quoting of values. Leading or trailing space is trimmed from values.

- **Type**: `text/x-unquoted-csv`

```peml
[.assets.test.files]
type: text/x-unquoted-csv
pattern.method_call: calculate({{a}}, {{b}}, {{op}})
content:----------
a, b, op, expected
10, 20, "add", 30
----------
[]
```

### **YAML**

Great for complex structures or when you want a clear vertical layout. Also useful if the data is program-generated. Note the use of `columns` metadata (see below) to indicate that "op" should be treated as a string value, since double-quotes would require escaping in YAML if they are to be included in the value.

- **Type**: `text/yaml`

```peml
[.assets.test.files]
type: text/yaml
pattern.method_call: calculate({{a}}, {{b}}, {{op}})
columns.op.format: String
content:----------
- a: 10
  b: 20
  op: add
  expected: 30
- a: 5
  b: 10
  c: add
  d: 15
----------
[]
```

### **YAML Flow**

A compact version of YAML where each test case is on a single line. The

- **Type**: `text/yaml`

```peml
[.assets.test.files]
type: text/yaml
pattern.method_call: calculate({{a}}, {{b}}, {{op}})
columns.op.format: String
content:----------
- { a: 10, b: 20, op: add, expected: 30 }
- { a: 5,  b: 10, op: add, expected: 15 }
----------
[]
```

### **JSON**

Standard format used by web APIs. Mostly useful for tool-generated data, since it is less friendly for human authoring. Here, the string literal for the "op" value includes double-quotes as part of the value, just like in the unquoted CSV. Column metadata could be used instead, if desired.

- **Type**: `application/json`

```peml
[.assets.test.files]
type: application/json
pattern.method_call: calculate({{a}}, {{b}}, {{op}})
content:----------
[
  { "a": 10, "b": 20, "op": "\"add\"", "expected": 30 }
]
----------
[]
```

### **Gherkin Tables**

Very readable "grid" format using pipes, borrowed from Gherkin notation. Gherkin is a Behavior-Driven Development language that supports this format for human-readable data tables in test specifications.

- **Type**: `text/x-gherkin-table`

```peml
[.assets.test.files]
type: text/x-gherkin-table
pattern.method_call: calculate({{a}}, {{b}}, {{op}})
content:----------
| a  | b  | op    | expected |
| 10 | 20 | "add" | 30       |
----------
[]
```

### **CSV**

Standard Comma Separated Values. This format is naturally supported by Excel and Google Sheets, and provides an easy way to take data tables authored in a spreadsheet and drop them in. However, its quoting style, which uses double-quotes around quoted cell values, where double-quote characters are represented by pairs of double-quote characters inside a quoted string, is error-prone for human authoring. For example, an empty string writen as `""` in programming text would be written as `""""""` in CSV, since it needs to be quoted, and each of the included double-quote characters must be escaped by repeating each twice (!). This format is only recommended for tool authoring, although you can sometimes use column metadata format options to fix the quoting obligations for simple string values.

- **Type**: `text/csv`

```peml
[.assets.test.files]
type: text/csv
pattern.method_call: calculate({{a}}, {{b}}, {{op}})
content:----------
a,b,op,expected
10,20,"""add""", 30
----------
[]
```

---

## 3. Pattern Interpolation

The `pattern.method_call` tells PEML how to use your data. Placeholders like `{{column_name}}` are replaced by the values in your table.

**Example:**
If your pattern is `logEvent({{user}}, {{id}}, {{action}})` and a row has `user: "alice", id: 101, action: "login"`, PEML generates a call like `logEvent("alice", 101, "login")`.

---

## 4. Column Metadata (`columns`)

Sometimes you need to give PEML more information about your data, especially for languages like Java that care about types. This is particularly useful if you want to use YAML flow style to represent structured data values, like arrays, lists, or maps (hashes). You can use the `columns` key to specify:

- **type**: The programming language type (e.g., `int[]`, `Map<String, Integer>`).
- **format**: How the data is written in the cell (use `yaml` if your cells contain YAML-style arrays or maps).

### Example with Metadata

```peml
[.assets.test.files]
type: text/x-unquoted-csv
pattern.method_call: processArray({{numbers}}, {{precision}}, {{label}})
columns.numbers.type: int[]
columns.numbers.format: yaml
content:----------
numbers, precision, label, expected
[1, 2, 3], 2, "mean", 2
[10, 20], 1, "sum", 30
----------
[]
```

PEML will see the YAML array `[1, 2, 3]` and generate the correct Java code: `new int[]{1, 2, 3}`. Arrays, lists, and maps are supported with arbitrary nesting. If you need support for a custom data type that can be constructed from this kind of structure, let us know (we can consider adding support for calling factory methods that take a parameter of one of these types).

---

## 5. Description Parsing (Tags)

You can add names or notes to your tests by including a `description` column. If you enable the `parse_descriptions` option, you can use tags:

- **example**: Marks a test as a visible example for students.
- **hidden**: Hides the test from students (internal grading).
- **screening**: Used for automatic pre-submission checks.

**In Gherkin:**

```gherkin
| a | b | op    | expected | description                        |
| 1 | 1 | "add" | 2        | example: Basic addition            |
| 0 | 0 | "add" | 0        | hidden: Check identity property    |
```

PEML will automatically strip the tag (like `example:`) and set the property on the test case. Alternatively, you can provide these as separate columns:

```gherkin
| a | b | op    | expected | description             | example | hidden |
| 1 | 1 | "add" | 2        | Basic addition          | true    |        |
| 0 | 0 | "add" | 0        | Check identity property |         | true   |
```

---

## 6. Checklist for Success

1. [ ] **Match Headers**: Your table headers must match the `{{placeholders}}` in your pattern.
2. [ ] **Choose Type**: Ensure the `type` field matches the format you wrote in `content`.
3. [ ] **Column Setup**: Use `columns.NAME.type` for complex types like arrays or lists.
4. [ ] **Delimiters**: Content blocks are wrapped in `----------` with an empty array `[]` at the end.
