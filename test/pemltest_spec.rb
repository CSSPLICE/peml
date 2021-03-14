require 'test_helper'

describe Peml do
  print_asts = true

  def assert_parses_nonterminal(nt, text, expected)
    begin
      parser = Peml::PemlTestParser.new
      actual = Peml::PemlTestAstCleaner.new.apply(
        parser.public_send(nt).parse(text)
      )
      actual.must_equal expected
    rescue Parslet::ParseFailed => e
      fail e.parse_failure_cause.ascii_tree
    end
  end

  it "parses an identifier" do
    input = 'Answer'
    expected = {id: 'Answer'}
    assert_parses_nonterminal :identifier, input, expected
  end

  # it "parses a suite start word with class name" do
  #   input = 'test: Answer'
  #   expected = {label: 'test', id: 'Answer'}
  #   assert_parses_nonterminal :suite_start_word, input, expected
  # end

  # it "parses a suite start word with description" do
  #   input = 'describe "Answer"'
  #   expected = {label: 'describe',
  #               message: {double_quoted_string: 'Answer'}}
  #   assert_parses_nonterminal :suite_start_word, input, expected
  # end

  # it "parses a suite start word with unquoted description" do
  #   input = 'check Answer goes here'
  #   expected = {label: 'check',
  #               description: {double_quoted_string: 'Answer'}}
  #   assert_parses_nonterminal :suite_start_word, input, expected
  # end

  describe "#pemltest_parse_file" do
    # Test that it successfully parses every positive example
    Dir.glob(File.expand_path('../PEMLtest/*.pemltest', __FILE__)).each do |f|
      slug = File.basename(f)

      it "parses #{slug}" do
        begin
          ast = Peml::pemltest_parse(filename: f)
          if print_asts
            puts "\nAST for #{slug}:"
            pp ast
            # puts ast.to_yaml
            puts ''
          end
          _(ast).wont_be_nil
        rescue Parslet::ParseFailed => e
          fail e.parse_failure_cause.ascii_tree
        end
      end
    end
  end

end
