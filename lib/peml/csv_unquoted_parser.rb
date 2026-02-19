require 'parslet'
require_relative 'utils'

module Peml

  class CsvUnquotedParser < Parslet::Parser

    root :lines

    rule(:lines) do
      line.as(:line).repeat
    end

    rule(:line) do
      line_spaces >> expression >>
        (comma >> line_spaces >> expression).repeat >>
        line_terminator
    end

    rule(:nested_code) do
      (str('{').as(:lb) >>
        nested_code.repeat.as(:body) >>
        str('}').as(:rb)).as(:balanced) |
        (str('(').as(:lb) >>
          nested_code.repeat.as(:body) >>
          str(')').as(:rb)).as(:balanced) |
        (str('[').as(:lb) >>
          nested_code.repeat.as(:body) >>
          str(']').as(:rb)).as(:balanced) |
        single_quoted_string |
        double_quoted_string |
        regex |
        match('[^\{\}\(\)\[\]\"\']').as(:text)
    end

    rule(:string) do
      (single_quoted_string | double_quoted_string | regex | unquoted_string)
    end

    rule(:expression) do
      unquoted_expression
    end

    rule(:unquoted_expression) do
        (unquoted_string_terminator.absent? >> nested_code).
          repeat(1).as(:expr)
    end

    rule(:unquoted_string) do
        match('[\{\}\"\'\(\)\[\]]').absent? >>
        (unquoted_string_terminator.absent? >> match('[^\r\n,]')).
          repeat(1).as(:string)
    end

    rule(:comma) do
      line_spaces >> str(',')
    end

    rule(:unquoted_string_terminator) do
      comma | line_terminator
    end

    rule(:line_terminator) do
      line_spaces >> match('[\r]').maybe >> (str("\n") | any.absent?)
    end

    rule :double_quoted_string do
      (str('"').as(:lb) >>
        (
          (str('\\') >> any) |
          (str('"').absent? >> any)
        ).repeat.as(:body) >>
        str('"').as(:rb)).as(:balanced).as(:string)
    end

    rule :single_quoted_string do
      (str("'").as(:lb) >>
        (
        (str('\\') >> any) |
          (str("'").absent? >> any)
        ).repeat.as(:body) >>
        str("'").as(:rb)).as(:balanced).as(:string)
    end

    rule :regex do
      (str('/').as(:lb) >>
        (
        (str('\\') >> any) |
          (str('/').absent? >> any)
        ).repeat.as(:body) >>
        str('/').as(:rb) >> match('[a-z]').repeat.as(:modifiers)).
        as(:balanced).as(:regex)
    end

    rule(:space?) do
      match('\s').repeat
    end

    rule(:line_spaces) do
      match('[ \t]').repeat
    end

    def parse(text, reporter = nil)
      if !reporter
        reporter = Parslet::ErrorReporter::Deepest.new
      end
      ast = super(text, reporter: reporter)
      # puts "AST before cleaning:"
      # pp ast
      ast = CsvUnquotedAstCleaner.new.apply(ast)
      if ast.length() > 0 && !ast[0].kind_of?(Array)
        # In this case, there must be a one-line CSV result, so nest it
        ast = [ast]
      end
      # puts "AST after cleaning:"
      # pp ast
      return ast
    end

  end

  class CsvUnquotedAstCleaner < Parslet::Transform

    rule(simple(:x)) do
      x.to_s
    end

    rule(unquoted_string: subtree(:text)) do
      {unquoted_string: Utils::string_reduce(text)}
    end

    rule(balanced: { lb: simple(:lb),
                     body: subtree(:body),
                     rb: simple(:rb) }) do
      reduced = Utils::string_reduce(body)
      if reduced.is_a?(Array)
        reduced = reduced.map { |v|
          v.is_a?(Hash) && v.key?(:text) ? v[:text] : v.to_s
        }.join
      end
      lb.to_s + reduced + rb.to_s
    end

    rule(expr: subtree(:expr)) do
      Utils::string_reduce(expr)
    end

    rule(line: subtree(:expr)) do
      expr.is_a?(Array) ? expr : [expr]
    end

  end

end
