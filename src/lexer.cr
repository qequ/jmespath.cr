require "json"
require "set"
require "./exceptions"

class Lexer
  property current : Char? # @current can be a Char or Nil, initialized later
  property expression : String = ""
  property chars : Array(Char) = [] of Char
  property position : Int32 = 0
  property length : Int32 = 0

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

  def initialize
    @current = nil
    @position = 0
    @length = 0
    @chars = [] of Char
    @expression = ""
  end

  def tokenize(expression : String) : Array(Hash(String, Char | Int32 | String | Nil) | Hash(String, Int32 | String))
    raise EmptyExpressionError.new if expression.empty?
    @expression = expression
    @chars = @expression.chars
    @position = 0
    @length = @expression.size
    @current = @length > 0 ? @chars[0]? : nil

    tokens = [] of (Hash(String, Char | Int32 | String | Nil) | Hash(String, Int32 | String))
    while @current
      if SIMPLE_TOKENS.keys.includes?(@current)
        token = token(@current, SIMPLE_TOKENS[@current]).tap { next_char }
      elsif START_IDENTIFIER.includes?(@current)
        token = identifier
      elsif WHITESPACE.includes?(@current)
        next_char
        token = nil
      elsif @current == '['
        token = handle_bracket
      elsif @current == "'"
        token = consume_raw_string_literal
      elsif @current == '|'
        token = match_or_else('|', "or", "pipe")
      elsif @current == '&'
        token = match_or_else('&', "and", "expref")
      elsif @current == '`'
        token = consume_literal
      elsif VALID_NUMBER.includes?(@current)
        token = number
      elsif @current == '-'
        token = negative_number
      elsif @current == '"'
        token = consume_quoted_identifier
      else
        raise LexerError.new(@position, @current.to_s, "Unknown token #{@current}")
      end
      tokens << token if token
    end
    tokens << eof_token unless tokens.empty? || tokens.last["type"] == "eof"
    tokens
  end

  private def token(value, type)
    {"type" => type, "value" => value, "start" => @position, "end" => @position + 1}
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

  private def identifier : Hash(String, String | Int32)
    start = @position
    buffer = String.build do |str|
      str << @current.to_s
      next_char
      while VALID_IDENTIFIER.includes?(@current)
        str << @current.to_s
        next_char
      end
    end
    {"type" => "unquoted_identifier", "value" => buffer, "start" => start, "end" => @position}
  end

  private def handle_bracket : Hash(String, String | Int32)
    start = @position
    next_char
    case @current
    when ']'
      next_char
      {"type" => "flatten", "value" => "[]", "start" => start, "end" => @position}
    when '?'
      next_char
      {"type" => "filter", "value" => "[?", "start" => start, "end" => @position}
    else
      {"type" => "lbracket", "value" => "[", "start" => start, "end" => @position}
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

  private def consume_raw_string_literal : Hash(String, String | Int32)
    start = @position
    buffer = consume_until('\'')
    {"type" => "literal", "value" => buffer, "start" => start, "end" => @position}
  end

  private def consume_quoted_identifier : Hash(String, String | Int32)
    start = @position
    buffer = consume_until('"')
    begin
      parsed_value = JSON.parse(%Q["#{buffer}"])
      # Emsure the value is a string or Int32
      value = case parsed_value
              when JSON::Any
                parsed_value.as_i? || parsed_value.as_s
              else
                parsed_value.to_s
              end
      raise LexerError.new(@position, buffer, "Invalid JSON value type") unless value
      {"type" => "quoted_identifier", "value" => value, "start" => start, "end" => @position}
    rescue ex : JSON::ParseException
      raise LexerError.new(@position, buffer, "Invalid JSON format: #{ex.message}")
    end
  end

  private def parse_value(parsed_value)
    case parsed_value
    when JSON::Any
      parsed_value.as_i? || parsed_value.as_s
    else
      parsed_value.to_s
    end
  end

  private def consume_literal : Hash(String, String | Int32)
    start = @position
    lexeme = consume_until('`')
    begin
      parsed_value = JSON.parse(lexeme)
      value = parse_value(parsed_value)
      raise LexerError.new(@position, lexeme, "Invalid JSON value type") unless value
      {"type" => "literal", "value" => value, "start" => start, "end" => @position}
    rescue ex : JSON::ParseException
      # Invalid JSON values should be converted to quoted
      # JSON strings during the JEP-12 deprecation period.
      # call JSON.parse with the string wrapped in double quotes
      parsed_value = JSON.parse(%Q["#{lexeme}"])
      value = parse_value(parsed_value)
      raise LexerError.new(@position, lexeme, "Invalid JSON format: #{ex.message}") unless value
      {"type" => "quoted_identifier", "value" => value, "start" => start, "end" => @position}
    end
  end

  private def match_or_else(expected : Char, match_type : String, else_type : String) : Hash(String, String | Int32)
    start = @position
    current = @current.to_s
    nc = next_char()
    if @current == expected
      next_char
      {"type" => match_type, "value" => "#{current}#{nc}", "start" => start, "end" => start + 1}
    else
      {"type" => else_type, "value" => "#{current}", "start" => start, "end" => start}
    end
  end

  private def consume_number : String
    buffer = String.build do |str|
      str << @current.to_s
      while VALID_NUMBER.includes?(next_char) && !@current.nil?
        str << @current.to_s
      end
    end
    buffer
  end

  private def number : Hash(String, String | Int32)
    start = @position
    number_string = consume_number
    {"type" => "number", "value" => number_string.to_i, "start" => start, "end" => @position}
  end

  private def negative_number : Hash(String, String | Int32)
    start = @position
    next_char
    if VALID_NUMBER.includes?(@current)
      number_string = "-" + consume_number
      {"type" => "number", "value" => number_string.to_i32, "start" => start, "end" => @position}
    else
      raise LexerError.new(@position, @current.to_s, "Unknown token '-'")
    end
  end

  private def equal_sign : Hash(String, String | Int32)
    start = @position
    if next_char == '='
      next_char
      {"type" => "eq", "value" => "==", "start" => start, "end" => @position}
    else
      position = @current.nil? ? @position : @position - 1
      raise LexerError.new(position, "=", "Unknown token '='")
    end
  end

  private def eof_token : Hash(String, String | Int32)
    {"type" => "eof", "value" => "", "start" => @length, "end" => @length}
  end
end
