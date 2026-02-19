require 'test_helper'
require 'peml/csv_unquoted_parser'

describe Peml::CsvUnquotedParser do
  before do
    @parser = Peml::CsvUnquotedParser.new
  end

  # ----- Basic structure -----

  describe "basic CSV structure" do
    it "parses a single value on one line" do
      result = @parser.parse("hello\n")
      _(result).must_equal [["hello"]]
    end

    it "parses a single row with multiple columns" do
      result = @parser.parse("a,b,c\n")
      _(result).must_equal [["a", "b", "c"]]
    end

    it "parses multiple rows" do
      result = @parser.parse("a,b\n1,2\n3,4\n")
      _(result).must_equal [["a", "b"], ["1", "2"], ["3", "4"]]
    end

    it "handles empty input" do
      result = @parser.parse("")
      _(result).must_equal ""
    end
  end

  # ----- Whitespace handling -----

  describe "whitespace handling" do
    it "ignores leading spaces in values" do
      result = @parser.parse("  a,  b\n")
      _(result).must_equal [["a", "b"]]
    end

    it "ignores leading tabs in values" do
      result = @parser.parse("a,\tb\n")
      _(result).must_equal [["a", "b"]]
    end

    it "handles CRLF line endings" do
      result = @parser.parse("a,b\r\n1,2\r\n")
      _(result).must_equal [["a", "b"], ["1", "2"]]
    end

    it "handles input without trailing newline" do
      result = @parser.parse("a,b")
      _(result).must_equal [["a", "b"]]
    end
  end

  # ----- Numeric-style CSV (header + data rows) -----

  describe "numeric data" do
    it "parses a header row with numeric data rows" do
      csv = "x,y,expected\n6,4,2\n27,9,9\n"
      result = @parser.parse(csv)
      _(result).must_equal [
        ["x", "y", "expected"],
        ["6", "4", "2"],
        ["27", "9", "9"]
      ]
    end

    it "parses GCD-style test data from PEML exercises" do
      csv = "x,y,expected,description\n6,4,2,example\n27,9,9\n25,5,5\n"
      result = @parser.parse(csv)
      _(result).must_equal [
        ["x", "y", "expected", "description"],
        ["6", "4", "2", "example"],
        ["27", "9", "9"],
        ["25", "5", "5"]
      ]
    end
  end

  # ----- Double-quoted strings -----

  describe "double-quoted strings" do
    it "parses a simple double-quoted string" do
      result = @parser.parse("\"hello\",value\n")
      _(result).must_equal [["\"hello\"", "value"]]
    end

    it "preserves commas inside double-quoted strings" do
      result = @parser.parse("\"a, b\",c\n")
      _(result).must_equal [["\"a, b\"", "c"]]
    end

    it "handles escaped characters in double-quoted strings" do
      result = @parser.parse("\"hello\\\"world\",value\n")
      _(result).must_equal [["\"hello\\\"world\"", "value"]]
    end
  end

  # ----- Single-quoted strings -----

  describe "single-quoted strings" do
    it "parses a single-quoted string field" do
      result = @parser.parse("'hello world',42\n")
      _(result).must_equal [["'hello world'", "42"]]
    end

    it "handles escaped characters in single-quoted strings" do
      result = @parser.parse("'it\\'s',value\n")
      _(result).must_equal [["'it\\'s'", "value"]]
    end
  end

  # ----- Nested brackets/parens (code expressions) -----

  describe "nested brackets and parentheses" do
    it "treats commas inside parentheses as part of expression" do
      result = @parser.parse("fn(a, b),expected\n")
      _(result).must_equal [["fn(a, b)", "expected"]]
    end

    it "treats commas inside curly braces as part of expression" do
      result = @parser.parse("new int[] {1, 2, 3},true\n")
      _(result).must_equal [["new int[] {1, 2, 3}", "true"]]
    end

    it "treats commas inside square brackets as part of expression" do
      result = @parser.parse("arr[0, 1],value\n")
      _(result).must_equal [["arr[0, 1]", "value"]]
    end

    it "handles deeply nested brackets" do
      result = @parser.parse("fn({a, {b, c}}),done\n")
      _(result).must_equal [["fn({a, {b, c}})", "done"]]
    end

    it "handles mixed bracket types" do
      result = @parser.parse("fn({a: [1, 2]}),ok\n")
      _(result).must_equal [["fn({a: [1, 2]})", "ok"]]
    end
  end

  # ----- Quoted strings with nested code (real PEML patterns) -----

  describe "PEML-style test data with quoted Java expressions" do
    it "parses hasOdd-style data with quoted array constructors" do
      csv = <<~CSV
        nums,expected,description
        "new int[] {12, 7, 8, 25, 3}",true,example
        "new int[] {1}",true
        "new int[] {}",false
      CSV
      result = @parser.parse(csv)
      _(result).must_equal [
        ["nums", "expected", "description"],
        ['"new int[] {12, 7, 8, 25, 3}"', "true", "example"],
        ['"new int[] {1}"', "true"],
        ['"new int[] {}"', "false"]
      ]
    end
  end

  # ----- Regex literals -----

  describe "regex literals" do
    it "parses a regex literal field" do
      result = @parser.parse("/abc/i,value\n")
      _(result).must_equal [["/abc/i", "value"]]
    end

    it "parses a regex without modifiers" do
      result = @parser.parse("/pattern/,value\n")
      _(result).must_equal [["/pattern/", "value"]]
    end

    it "parses a regex with multiple modifiers" do
      result = @parser.parse("/pattern/gi,value\n")
      _(result).must_equal [["/pattern/gi", "value"]]
    end
  end

  # ----- Edge cases -----

  describe "edge cases" do
    it "handles a single column with multiple rows" do
      result = @parser.parse("a\nb\nc\n")
      _(result).must_equal [["a"], ["b"], ["c"]]
    end

    it "handles boolean-like values" do
      result = @parser.parse("flag,expected\ntrue,false\n")
      _(result).must_equal [["flag", "expected"], ["true", "false"]]
    end

    it "handles values with special characters that are not delimiters" do
      result = @parser.parse("a.b,c+d,e-f\n")
      _(result).must_equal [["a.b", "c+d", "e-f"]]
    end
  end

end
