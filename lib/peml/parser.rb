require 'parslet'

module Peml

  class PemlTestParser < Parslet::Parser

    root :suite

    rule(:suite) do
      space? >>
        suite_start_word >>
        left_brace >>
        description.maybe >>
        imports.maybe >>
        givens.maybe >>
        invariants.maybe >>
        whens.maybe >>
        thens.maybe >>
        finallys.maybe >>
        suite.repeat.as(:suites) >>
        right_brace
    end

    rule(:suite_start_word) do
      (str('check') |
        str('test') |
        str('describe') |
        str('context')).as(:label) >>
        (identifier_char | str('(')).absent? >>
        space? >>
        ( colon.maybe >>
          (identifier >> space? >> left_brace.present? |
            expression.as(:message)) >> space? >> left_brace.present?).maybe
    end

    rule(:description) do
      (description_header >>
        (string.as(:line) >> space?).repeat(1).as(:lines)).as(:description)
    end

    rule(:description_header) do
      (str('scenario') | str('description')).as(:label) >> space? >> colon
    end

    rule(:imports) do
      import_header >>
        (clause_body >>
          (import_header.maybe >> clause_body).repeat.as(:imports)
        ).as(:imports) >>
        space?
    end

    rule(:import_header) do
      str('import') >> str('s').maybe >> space? >> colon
    end

    rule(:givens) do
      given_header >>
        (clause_body >>
          (given_header.maybe >> clause_body).repeat.as(:givens)
        ).as(:givens) >>
        space?
    end

    rule(:given_header) do
      str('given') >> str('s').maybe >> space? >> colon
    end

    rule(:invariants) do
      invariant_header >>
        (clause_body >>
          (invariant_header.maybe >> clause_body).repeat.as(:invariants)
        ).as(:invariants) >>
        space?
    end

    rule(:invariant_header) do
      str('invariant') >> str('s').maybe >> space? >> colon
    end

    rule(:whens) do
      when_header >>
        (clause_body >>
          (when_header.maybe >> clause_body).repeat.as(:whens)
        ).as(:whens) >>
        space?
    end

    rule(:when_header) do
      str('when') >> str('s').maybe >> space? >> colon
    end

    rule(:thens) do
      then_header >>
        (clause_body >>
          (then_header.maybe >> clause_body).repeat.as(:thens)
        ).as(:thens) >>
        space?
    end

    rule(:then_header) do
      str('then') >> str('s').maybe >> space? >> colon
    end

    rule(:finallys) do
      finally_header >>
        (clause_body >>
          (finally_header.maybe >> clause_body).repeat.as(:finallys)
        ).as(:finallys) >>
        space?
    end

    rule(:finally_header) do
      str('finally') >> str('s').maybe >> space? >> colon
    end

    rule(:clause_body) do
      (expression.as(:expr) | code_block) >> space?
    end

    rule(:reserved_word_start) do
      (str('import') | str('given') | str('when') |
        str('then') | str('invariant') | str('finally')) >>
        str('s').maybe >> space? >> colon
    end

    rule :code_block do
      (str('{') >>
        nested_code.repeat >>
        str('}')).as(:block)
    end

    rule(:nested_code) do
      str('{') >> nested_code.repeat >> str('}') |
        str('(') >> nested_code.repeat >> str(')') |
        str('[') >> nested_code.repeat >> str(']') |
        block_comment |
        line_comment |
        match('[^\{\}\(\)\[\]]')
    end

    rule(:colon) do
      str(':') >> space?
    end

    rule(:left_brace) do
      str('{') >> space?
    end

    rule(:right_brace) do
      str('}') >> space?
    end

    rule(:identifier_start_char) do
      match('[A-Za-z_\$]')
    end

    rule(:identifier_char) do
      match('[A-Za-z0-9_!\-\?\$\.]')
    end

    rule(:identifier) do
      (identifier_start_char >> identifier_char.repeat).as(:id)
    end

    rule(:string) do
      (single_quoted_string | double_quoted_string | unquoted_string)
    end

    rule(:expression) do
      (single_quoted_string | double_quoted_string | unquoted_expression)
    end

    rule(:unquoted_expression) do
      reserved_word_start.absent? >>
        suite_start_word.absent? >>
        match('[\{\}\"\'\(\)\[\]]').absent? >>
        (unquoted_string_terminator.absent? >> nested_code).
          repeat(1).as(:unquoted_string) >>
        unquoted_string_terminator
    end

    rule(:unquoted_string) do
      reserved_word_start.absent? >>
        suite_start_word.absent? >>
        match('[\{\}\"\'\(\)\[\]]').absent? >>
        (unquoted_string_terminator.absent? >> match('[^\r\n]')).
          repeat(1).as(:unquoted_string) >>
        unquoted_string_terminator
    end

    rule(:unquoted_string_terminator) do
      match('[ \t]').repeat >>
        (line_comment | match('[\r]').maybe >> str("\n"))
    end

    rule :double_quoted_string do
      (str('"') >>
        (
          (str('\\') >> any) |
          (str('"').absent? >> any)
        ).repeat.as(:double_quoted_string) >>
        str('"'))
    end

    rule :single_quoted_string do
      (str("'") >>
        (
        (str('\\') >> any) |
          (str("'").absent? >> any)
        ).repeat.as(:singe_quoted_string) >>
        str("'"))
    end

    rule(:space?) do
      space.maybe
    end

    rule(:space) do
      (block_comment | line_comment | whitespace).repeat(1)
    end

    rule(:whitespace) do
      match('\s')
    end

    rule(:block_comment) do
      str('/*') >>
        (str('*/').absent? >> any).repeat >>
        str('*/')
    end

    rule (:line_comment) do
      (str('//') | str('#')) >>
        (str("\n").absent? >> any).repeat >>
        str("\n")
    end

    def parse(text)
      ast = super(text)
      #puts "AST before cleaning:"
      #pp ast
      ast = PemlTestAstCleaner.new.apply(ast)
      #puts "AST after cleaning:"
      #pp ast
      return ast
    end

  end

  class PemlTestAstCleaner < Parslet::Transform
    # rule(unquoted_string: simple(:string)) do
    #   string.to_s
    # end
    # rule(string: simple(:string)) do
    #   string.to_s
    # end
    rule(int: simple(:int)) do
      int.to_i
    end
    rule(id: simple(:string)) do
      { id: string.to_s }
    end
    # rule(expr: simple(:string)) do
    #   { expr: PemlTestAstCleaner.unquote(string.to_s) }
    # end
    rule(block: simple(:string)) do
      { block: string.to_s }
    end
    rule(simple(:x)) do
      x.to_s
    end
    rule(expr: subtree(:expr), imports: subtree(:y)) do
      y.unshift( { expr: expr } )
    end
    rule(block: simple(:expr), imports: subtree(:y)) do
      y.unshift( { block: expr} )
    end
    rule(expr: subtree(:expr), givens: subtree(:y)) do
      y.unshift( { expr: expr } )
    end
    rule(block: simple(:expr), givens: subtree(:y)) do
      y.unshift( { block: expr} )
    end
    rule(expr: subtree(:expr), whens: subtree(:y)) do
      y.unshift( { expr: expr } )
    end
    rule(block: simple(:expr), whens: subtree(:y)) do
      y.unshift( { block: expr} )
    end
    rule(expr: subtree(:expr), thens: subtree(:y)) do
      y.unshift( { expr: expr } )
    end
    rule(block: simple(:expr), thens: subtree(:y)) do
      y.unshift( { block: expr} )
    end
    rule(expr: subtree(:expr), finallys: subtree(:y)) do
      y.unshift( { expr: expr } )
    end
    rule(block: simple(:expr), finallys: subtree(:y)) do
      y.unshift( { block: expr} )
    end
    rule(line: {unquoted_string: simple(:s)}) do
      s.to_s
    end

    def self.unquote(s)
      if s.start_with?('"') && s.end_with?('"') ||
        s.start_with?("'") && s.end_with?("'")
        s[1..-2]
      else
        s
      end
    end

  end

end
