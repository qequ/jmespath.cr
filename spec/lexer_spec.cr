require "./spec_helper"
require "../src/lexer" # Adjust path as necessary

describe Lexer do
  describe "Tokenizing input" do
    lexer = Lexer.new

    it "handles empty strings" do
      expect_raises(EmptyExpressionError) do
        lexer.tokenize("")
      end
    end

    it "tokenizes unquoted identifiers" do
      tokens = lexer.tokenize("foo")
      tokens.any? { |token| token.type == "unquoted_identifier" && token.value == "foo" && token.start == 0 && token.end == 3 }.should be_true
    end

    it "tokenizes number" do
      tokens = lexer.tokenize("123")
      tokens.any? { |token| token.type == "number" && token.value == 123 && token.start == 0 && token.end == 3 }.should be_true
    end

    it "tokenized negative number" do
      tokens = lexer.tokenize("-123")
      tokens.any? { |token| token.type == "number" && token.value == -123 && token.start == 0 && token.end == 4 }.should be_true
    end

    it "tokenizes quoted identifier" do
      tokens = lexer.tokenize("\"foo\"")
      tokens.any? { |token| token.type == "quoted_identifier" && token.value == "foo" && token.start == 0 && token.end == 5 }.should be_true
    end

    it "tokenizes dot expressions" do
      tokens = lexer.tokenize("foo.bar.baz")
      expected_tokens = [
        Token.new("unquoted_identifier", "foo", 0, 3),
        Token.new("dot", '.', 3, 4),
        Token.new("unquoted_identifier", "bar", 4, 7),
        Token.new("dot", '.', 7, 8),
        Token.new("unquoted_identifier", "baz", 8, 11),
        Token.new("eof", "", nil, nil),
      ]
      tokens.should eq(expected_tokens)
    end

    it "tokenizes complex expressions" do
      tokens = lexer.tokenize("foo.bar[*].baz | a || b")
      expected_tokens = [
        Token.new("unquoted_identifier", "foo", 0, 3),
        Token.new("dot", '.', 3, 4),
        Token.new("unquoted_identifier", "bar", 4, 7),
        Token.new("lbracket", "[", 7, 8),
        Token.new("star", '*', 8, 9),
        Token.new("rbracket", ']', 9, 10),
        Token.new("dot", '.', 10, 11),
        Token.new("unquoted_identifier", "baz", 11, 14),
        Token.new("pipe", "|", 15, 15),
        Token.new("unquoted_identifier", "a", 17, 18),
        Token.new("or", "||", 19, 20),
        Token.new("unquoted_identifier", "b", 22, 23),
        Token.new("eof", "", nil, nil),
      ]
      tokens.each_with_index do |token, index|
        token.should eq(expected_tokens[index])
      end
      tokens.should eq(expected_tokens)
    end

    it "raises an error for unknown character" do
      expect_raises(LexerError) do
        tokens = lexer.tokenize("foo[0^]")
      end
    end

    it "raises an error for bad first character" do
      expect_raises(LexerError) do
        tokens = lexer.tokenize("^foo[0]")
      end
    end

    it "raises an error for unknown character with identifier" do
      expect_raises(LexerError, "Unknown token") do
        tokens = lexer.tokenize("foo-bar")
      end
    end
  end
end
