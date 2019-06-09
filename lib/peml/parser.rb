require 'parslet'

module Peml

  class PemlTestParser < Parslet::Parser

    rule(:suite) do
      space? >>
        suite_start_word >>
        left_brace >>
        imports.maybe >>
        givens.maybe >>
        whens.maybe >>
        thens.maybe >>
        right_brace
    end

    rule(:suite_start_word) do
      (str('check') |
        str('test') |
        str('describe') |
        str('context')).as(:label) >>
        space? >>
        ( colon.maybe >>
          (identifier | string.as(:description)) >>
          space?).maybe
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

    rule(:clause_body) do
      (string.as(:expr) | code_block) >> space?
    end

    rule(:reserved_word_start) do
      (str('import') | str('given') | str('when') | str('then')) >>
        str('s').maybe >> space? >> colon
    end

    rule :code_block do
      (str('{') >>
        (str('}').absent? >> any).repeat >>
        str('}')).as(:block)
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

    rule(:identifier) do
      (match('[A-Za-z_\$]') >>
        match('[A-Za-z0-9_!\-\?\$\.]').repeat).as(:id)
    end

    rule(:string) do
      (single_quoted_string | double_quoted_string | unquoted_string)
    end

    rule(:unquoted_string) do
      reserved_word_start.absent? >>
        match('[\{\}\"\'\(\)\[\]]').absent? >>
        match('[^\r\n]').repeat(1).as(:unquoted_string) >>
        match('[\r]').maybe >> str("\n")
    end

    rule :double_quoted_string do
      (str('"') >>
        (
          (str('\\') >> any) |
          (str('"').absent? >> any)
        ).repeat >>
        str('"')).as(:string)
    end

    rule :single_quoted_string do
      (str("'") >>
        (
        (str('\\') >> any) |
          (str("'").absent? >> any)
        ).repeat >>
        str("'")).as(:string)
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

    root(:suite)

    def parse(text)
      ast = super(text)
      #puts "AST before cleaning:"
      #pp ast
      ast = PemlTestAstCleaner.new.apply(ast)
      #puts "AST after cleaning:"
      #pp ast
      return  ast
    end

  end

  class PemlTestAstCleaner < Parslet::Transform
    rule(unquoted_string: simple(:string)) do
      string.to_s
    end
    rule(string: simple(:string)) do
      string.to_s
    end
    rule(int: simple(:int)) do
      int.to_i
    end
    rule(id: simple(:string)) do
      { id: string.to_s }
    end
    rule(expr: simple(:string)) do
      { expr: PemlTestAstCleaner.unquote(string.to_s) }
    end
    rule(block: simple(:string)) do
      { block: string.to_s }
    end
    rule(simple(:x)) do
      x.to_s
    end
    rule(expr: simple(:expr), imports: subtree(:y)) do
      y.unshift( { expr: PemlTestAstCleaner.unquote(expr)} )
    end
    rule(block: simple(:expr), imports: subtree(:y)) do
      y.unshift( { block: expr} )
    end
    rule(expr: simple(:expr), givens: subtree(:y)) do
      y.unshift( { expr: PemlTestAstCleaner.unquote(expr)} )
    end
    rule(block: simple(:expr), givens: subtree(:y)) do
      y.unshift( { block: expr} )
    end
    rule(expr: simple(:expr), whens: subtree(:y)) do
      y.unshift( { expr: PemlTestAstCleaner.unquote(expr)} )
    end
    rule(block: simple(:expr), whens: subtree(:y)) do
      y.unshift( { block: expr} )
    end
    rule(expr: simple(:expr), thens: subtree(:y)) do
      y.unshift( { expr: PemlTestAstCleaner.unquote(expr)} )
    end
    rule(block: simple(:expr), thens: subtree(:y)) do
      y.unshift( { block: expr} )
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
