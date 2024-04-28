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
  end
end
