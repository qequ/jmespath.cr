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
      # primt tokens
      puts tokens
      puts "hello"
      tokens.any? { |token| token["type"] == "unquoted_identifier" && token["value"] == "foo" && token["start"] == 0 && token["end"] == 3 }.should be_true
    end

    it "tokenizes number" do
      tokens = lexer.tokenize("123")
      tokens.any? { |token| token["type"] == "number" && token["value"] == 123 && token["start"] == 0 && token["end"] == 3 }.should be_true
    end

    it "tokenized negative number" do
      tokens = lexer.tokenize("-123")
      tokens.any? { |token| token["type"] == "number" && token["value"] == -123 && token["start"] == 0 && token["end"] == 4 }.should be_true
    end

    it "tokenizes quoted identifier" do
      tokens = lexer.tokenize("\"foo\"")
      tokens.any? { |token| token["type"] == "quoted_identifier" && token["value"] == "foo" && token["start"] == 0 && token["end"] == 5 }.should be_true
    end
    it "tokenizes dot expressions" do
      tokens = lexer.tokenize("foo.bar.baz")
      expected_tokens = [
        {"type" => "unquoted_identifier", "value" => "foo", "start" => 0, "end" => 3},
        {"type" => "dot", "value" => '.', "start" => 3, "end" => 4},
        {"type" => "unquoted_identifier", "value" => "bar", "start" => 4, "end" => 7},
        {"type" => "dot", "value" => '.', "start" => 7, "end" => 8},
        {"type" => "unquoted_identifier", "value" => "baz", "start" => 8, "end" => 11},
        {"type" => "eof", "value" => "", "start" => 11, "end" => 11},
      ]
      tokens.should eq(expected_tokens)
    end

    it "tokenizes complex expressions" do
      tokens = lexer.tokenize("foo.bar[*].baz | a || b")
      expected_tokens = [
        {"type" => "unquoted_identifier", "value" => "foo", "start" => 0, "end" => 3},
        {"type" => "dot", "value" => '.', "start" => 3, "end" => 4},
        {"type" => "unquoted_identifier", "value" => "bar", "start" => 4, "end" => 7},
        {"type" => "lbracket", "value" => "[", "start" => 7, "end" => 8},
        {"type" => "star", "value" => '*', "start" => 8, "end" => 9},
        {"type" => "rbracket", "value" => ']', "start" => 9, "end" => 10},
        {"type" => "dot", "value" => '.', "start" => 10, "end" => 11},
        {"type" => "unquoted_identifier", "value" => "baz", "start" => 11, "end" => 14},
        {"type" => "pipe", "value" => "|", "start" => 15, "end" => 15},
        {"type" => "unquoted_identifier", "value" => "a", "start" => 17, "end" => 18},
        {"type" => "or", "value" => "||", "start" => 19, "end" => 20},
        {"type" => "unquoted_identifier", "value" => "b", "start" => 22, "end" => 23},
        {"type" => "eof", "value" => "", "start" => 23, "end" => 23},
      ]
      # go line by line and check if the tokens are equal
      tokens.each_with_index do |token, index|
        token.should eq(expected_tokens[index])
      end
      tokens.should eq(expected_tokens)
    end
  end
end
