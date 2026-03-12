require 'test_helper'
require 'peml/utils'

describe "Peml::Utils.parse_gherkin_table" do

  it "parses a simple valid table" do
    content = <<~GHERKIN
      | name  | age |
      | Alice | 30  |
      | Bob   | 25  |
    GHERKIN
    expected = [
      { 'name' => 'Alice', 'age' => '30' },
      { 'name' => 'Bob', 'age' => '25' }
    ]
    _(Peml::Utils.parse_gherkin_table(content)).must_equal expected
  end

  it "handles extra whitespace around pipes and cells" do
    content = "  |  name   |   age   |  \n  |  Alice  |   30    |  "
    expected = [{ 'name' => 'Alice', 'age' => '30' }]
    _(Peml::Utils.parse_gherkin_table(content)).must_equal expected
  end

  it "handles empty cells" do
    content = "| name | age |\n| Alice | |"
    expected = [{ 'name' => 'Alice', 'age' => '' }]
    _(Peml::Utils.parse_gherkin_table(content)).must_equal expected
  end

  it "ignores lines that do not start and end with a pipe" do
    content = <<~GHERKIN
      This is a comment
      | name | age |
      | Alice | 30 |
      And this is also ignored
    GHERKIN
    expected = [{ 'name' => 'Alice', 'age' => '30' }]
    _(Peml::Utils.parse_gherkin_table(content)).must_equal expected
  end

  it "returns an empty array for empty or nil input" do
    _(Peml::Utils.parse_gherkin_table("")).must_equal []
    _(Peml::Utils.parse_gherkin_table(nil)).must_equal []
  end

  it "handles a table with only a header row" do
    content = "| name | age |"
    _(Peml::Utils.parse_gherkin_table(content)).must_equal []
  end

  it "handles mismatched column counts by using tabular_to_hashes logic" do
    content = <<~GHERKIN
      | name | age |
      | Alice | 30 | 123 |
      | Bob |
    GHERKIN
    # tabular_to_hashes:
    # row 1 has 3 cells, but only 2 headers. It should take the first 2.
    # row 2 has 1 cell, but 2 headers. It should break and ignore 'age'.
    expected = [
      { 'name' => 'Alice', 'age' => '30' },
      { 'name' => 'Bob' }
    ]
    _(Peml::Utils.parse_gherkin_table(content)).must_equal expected
  end

end
