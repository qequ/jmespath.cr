require "json"
require "set"
require "./exceptions"

class Lexer
  property current : Char? # @current can be a Char or Nil
  START_IDENTIFIER = Set.new('a'..'z') + Set.new('A'..'Z') + Set{'_'}
  VALID_IDENTIFIER = START_IDENTIFIER + Set.new('0'..'9')
  VALID_NUMBER     = Set.new('0'..'9')
  WHITESPACE       = Set{' ', '\t', '\n', '\r'}
  SIMPLE_TOKENS    = {
    '.' => "dot",
    '*' => "star",
    ']' => "rbracket",
    ',' => "comma",
    ':' => "colon",
    '@' => "current",
    '(' => "lparen",
    ')' => "rparen",
    '{' => "lbrace",
    '}' => "rbrace",
  }

  def initialize(expression : String)
    raise EmptyExpressionError.new if expression.empty?
    @expression = expression
    @chars = @expression.chars
    @position = 0
    @length = @expression.size
    @current = @chars.size > 0 ? @chars[@position] : nil
  end

  def tokenize
    while @current
      case @current
      when SIMPLE_TOKENS.keys.includes?(@current)
        yield token(@current, SIMPLE_TOKENS[@current])
        next_char
      when START_IDENTIFIER.includes?(@current)
        yield identifier
      when WHITESPACE.includes?(@current)
        next_char
      when '['
        yield handle_bracket
      when "'"
        yield consume_raw_string_literal
      when '|'
        yield match_or_else('|', "or", "pipe")
      when '&'
        yield match_or_else('&', "and", "expref")
      when '`'
        yield consume_literal
      when VALID_NUMBER.includes?(@current)
        yield number
      when '-'
        yield negative_number
      when '"'
        yield consume_quoted_identifier
      when '<'
        yield match_or_else('=', "lte", "lt")
      when '>'
        yield match_or_else('=', "gte", "gt")
      when '!'
        yield match_or_else('=', "ne", "not")
      when '='
        yield equal_sign
      else
        raise LexerError.new("Unknown token #{@current}", @position, @current)
      end
      yield eof_token if @current.nil?
    end
  end

  private def token(value, type)
    {type: type, value: value, start: @position, end: @position + 1}
  end

  private def next_char : Char?
    @position += 1
    if @position < @length
      @current = @chars[@position]
    else
      @current = nil
    end
    @current
  end

  private def identifier
    start = @position
    buffer = String.build do |str|
      str << @current
      next_char # Advance to the next character for the loop condition check
      while VALID_IDENTIFIER.includes?(@current)
        str << @current
        next_char
      end
    end
    {type: "unquoted_identifier", value: buffer, start: start, end: @position}
  end

  private def handle_bracket
    start = @position
    next_char # Move past the '[' character

    case @current
    when ']'
      next_char # Move past the ']' character
      {type: "flatten", value: "[]", start: start, end: @position}
    when '?'
      next_char # Move past the '?' character
      {type: "filter", value: "[?", start: start, end: @position}
    else
      {type: "lbracket", value: "[", start: start, end: @position}
    end
  end

  private def consume_until(delimiter : Char) : String
    start = @position
    buffer = String.build do |str|
      next_char # Skip the opening delimiter
      while @current != delimiter && @current != nil
        if @current == '\\'
          next_char               # Skip the escape character
          str << (@current || "") # Append the next character, safely handle nil
        else
          str << @current
        end
        next_char
      end

      raise LexerError.new(@position, str.to_s, "Unclosed literal for delimiter '#{delimiter}'") if @current != delimiter
    end

    next_char # Move past the closing delimiter
    buffer.to_s
  end

  private def consume_raw_string_literal
    start = @position
    buffer = consume_until('\'')
    {type: "literal", value: buffer, start: start, end: @position}
  end

  private def consume_literal
    start = @position
    lexeme = consume_until('`')

    begin
      parsed_value = JSON.parse(lexeme)
    rescue ex : JSON::ParseException
      raise LexerError.new(@position, lexeme, "Invalid JSON literal")
    end

    {type: "literal", value: parsed_value, start: start, end: @position}
  end

  private def match_or_else(expected : Char, match_type : String, else_type : String)
    start = @position
    current = @current
    next_char = next_char() # Advance to the next character

    if next_char == expected
      next_char() # Move past the matched character
      {type: match_type, value: "#{current}#{next_char}", start: start, end: start + 1}
    else
      {type: else_type, value: "#{current}", start: start, end: start}
    end
  end

  private def consume_number : String
    buffer = String.build do |str|
      str << @current
      while VALID_NUMBER.includes?(next_char) && !@current.nil?
        str << @current
      end
    end

    buffer
  end

  private def number
    start = @position
    number_string = consume_number
    value = number_string.to_i
    {type: "number", value: value, start: start, end: @position}
  end

  private def negative_number
    start = @position
    next_char # Skip the '-' to check the next character
    if VALID_NUMBER.includes?(@current)
      number_string = "-" + consume_number # Prepend '-' to include it in the number
      value = number_string.to_i32         # Convert the string to an integer
      {type: "number", value: value, start: start, end: @position}
    else
      raise LexerError.new(@position, @current.to_s, "Unknown token '-'")
    end
  end

  private def consume_quoted_identifier
    start = @position
    lexeme = consume_until('"') # Assume consume_until skips the initial quote

    begin
      # Attempt to parse the lexeme as JSON to handle escaped characters correctly
      parsed_value = JSON.parse(%Q["#{lexeme}"])
      token_len = @position - start
      {type: "quoted_identifier", value: parsed_value, start: start, end: token_len}
    rescue ex : JSON::ParseException
      # Handle parsing errors and raise a LexerError with the error message
      raise LexerError.new(@position, lexeme, "Invalid JSON format: #{ex.message}")
    end
  end

  private def equal_sign
    start = @position
    if next_char == '=' # Check the character following the initial '='
      next_char         # Move past the second '='
      {type: "eq", value: "==", start: start, end: @position}
    else
      # Handle the error case where '=' is not followed by another '='
      # Crystal uses `nil` to signify EOF, so we check @current directly
      position = @current.nil? ? @position : @position - 1
      raise LexerError.new(position, '=', "Unknown token '='")
    end
  end

  private def eof_token
    {type: "eof", value: "", start: @length, end: @length}
  end
end
