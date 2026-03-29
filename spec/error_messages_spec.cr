require "./spec_helper"

describe "Error messages" do
  describe "ParseError" do
    it "reports correct position for trailing tokens" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("foo bar") }
      ex.lex_position.should eq(4)
      ex.message.not_nil!.should contain("foo bar")
      ex.message.not_nil!.should contain("at column 4")
    end

    it "reports correct position for unexpected token in expression" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("foo.||") }
      ex.message.not_nil!.should contain("foo.||")
    end

    it "reports correct position for invalid dot RHS" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("foo.)") }
      ex.lex_position.should eq(4)
      ex.message.not_nil!.should contain("foo.)")
      ex.message.not_nil!.should contain("at column 4")
    end

    it "reports correct position for unmatched bracket" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("foo[0") }
      ex.message.not_nil!.should contain("foo[0")
    end

    it "reports correct position for invalid slice syntax" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("foo[0:a]") }
      ex.lex_position.should eq(6)
      ex.message.not_nil!.should contain("foo[0:a]")
    end

    it "reports correct position for unmatched paren" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("(foo") }
      ex.message.not_nil!.should contain("(foo")
    end

    it "reports correct position for invalid bracket operation" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("foo[)") }
      ex.lex_position.should eq(4)
      ex.message.not_nil!.should contain("foo[)")
    end

    it "reports correct position for quoted identifier as function name" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("\"foo\"()") }
      ex.message.not_nil!.should contain("Quoted identifier not allowed for function names")
      ex.message.not_nil!.should contain("\"foo\"()")
    end

    it "reports position for invalid multi-select hash key" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("{123: foo}") }
      ex.message.not_nil!.should contain("{123: foo}")
    end

    it "includes expression and caret in error message" do
      parser = Parser.new
      ex = expect_raises(ParseError) { parser.parse("foo bar") }
      lines = ex.message.not_nil!.split("\n")
      # Should have: message line, expression line, caret line
      lines.size.should eq(3)
      lines[1].should eq("foo bar")
      lines[2].should contain("^")
    end
  end

  describe "LexerError" do
    it "reports correct position for unknown token" do
      lexer = Lexer.new
      ex = expect_raises(LexerError) { lexer.tokenize("foo^bar") }
      ex.lexer_position.should eq(3)
      ex.message.not_nil!.should contain("foo^bar")
      ex.message.not_nil!.should contain("^")
    end

    it "reports position for unknown token at start" do
      lexer = Lexer.new
      ex = expect_raises(LexerError) { lexer.tokenize("^foo") }
      ex.lexer_position.should eq(0)
      ex.message.not_nil!.should contain("^foo")
    end

    it "reports position for unclosed string literal" do
      lexer = Lexer.new
      ex = expect_raises(LexerError) { lexer.tokenize("'unclosed") }
      ex.message.not_nil!.should contain("Unclosed")
      ex.message.not_nil!.should contain("'unclosed")
    end

    it "reports position for unclosed backtick literal" do
      lexer = Lexer.new
      ex = expect_raises(LexerError) { lexer.tokenize("`unclosed") }
      ex.message.not_nil!.should contain("Unclosed")
      ex.message.not_nil!.should contain("`unclosed")
    end

    it "reports position for lone equals sign" do
      lexer = Lexer.new
      ex = expect_raises(LexerError) { lexer.tokenize("foo =") }
      ex.message.not_nil!.should contain("Unknown token '='")
    end

    it "reports position for invalid negative number" do
      lexer = Lexer.new
      ex = expect_raises(LexerError) { lexer.tokenize("foo[-abc]") }
      ex.message.not_nil!.should contain("Unknown token '-'")
      ex.message.not_nil!.should contain("foo[-abc]")
    end

    it "includes expression and caret in error message" do
      lexer = Lexer.new
      ex = expect_raises(LexerError) { lexer.tokenize("foo^bar") }
      lines = ex.message.not_nil!.split("\n")
      lines.size.should eq(3)
      lines[1].should eq("foo^bar")
      # Caret should be at position 3
      lines[2].should eq("   ^")
    end
  end

  describe "integration error messages" do
    it "JMESPath.search shows correct position" do
      ex = expect_raises(ParseError) { JMESPath.search("foo.[}", %({"foo": 1})) }
      ex.message.not_nil!.should contain("foo.[}")
    end

    it "shows position for deeply nested error" do
      ex = expect_raises(ParseError) { JMESPath.search("foo.bar.baz[0].qux.)", %({})) }
      ex.lex_position.should eq(19)
      ex.message.not_nil!.should contain("at column 19")
    end
  end
end
