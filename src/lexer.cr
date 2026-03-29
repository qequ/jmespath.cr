require "json"
require "set"
require "./exceptions"

struct Token
  property type : String
  property value : Char | Int32 | String | Nil
  property start : Char | Int32 | String | Nil
  property end : Char | Int32 | String | Nil
  property json_value : JSON::Any?

  NULL_TOKEN = Token.new("eof", "", nil, nil)

  def initialize(@type, @value, @start, @end, @json_value = nil)
  end
end

class Lexer
  property current : Char?
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

  def tokenize(expression : String) : Array(Token)
    raise EmptyExpressionError.new if expression.empty?
    @expression = expression
    @chars = @expression.chars
    @position = 0
    @length = @expression.size
    @current = @length > 0 ? @chars[0]? : nil

    tokens = [] of Token
    while @current
      if SIMPLE_TOKENS.keys.includes?(@current)
        tok = Token.new(SIMPLE_TOKENS[@current.not_nil!], @current, @position, @position + 1)
        next_char
        tokens << tok
      elsif START_IDENTIFIER.includes?(@current)
        tokens << identifier
      elsif WHITESPACE.includes?(@current)
        next_char
      elsif @current == '['
        tokens << handle_bracket
      elsif @current == '\''
        tokens << consume_raw_string_literal
      elsif @current == '|'
        tokens << match_or_else('|', "or", "pipe")
      elsif @current == '&'
        tokens << match_or_else('&', "and", "expref")
      elsif @current == '<'
        tokens << match_or_else('=', "lte", "lt")
      elsif @current == '>'
        tokens << match_or_else('=', "gte", "gt")
      elsif @current == '!'
        tokens << match_or_else('=', "ne", "not")
      elsif @current == '='
        tokens << equal_sign
      elsif @current == '`'
        tokens << consume_literal
      elsif VALID_NUMBER.includes?(@current)
        tokens << number
      elsif @current == '-'
        tokens << negative_number
      elsif @current == '"'
        tokens << consume_quoted_identifier
      else
        raise LexerError.new(@position, @current.to_s, "Unknown token '#{@current}'", @expression)
      end
    end
    tokens << Token::NULL_TOKEN unless tokens.empty? || tokens.last.type == "eof"
    tokens
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

  private def peek_char : Char?
    if @position + 1 < @length
      @chars[@position + 1]
    else
      nil
    end
  end

  private def identifier : Token
    start = @position
    buffer = String.build do |str|
      str << @current.to_s
      next_char
      while VALID_IDENTIFIER.includes?(@current)
        str << @current.to_s
        next_char
      end
    end
    Token.new("unquoted_identifier", buffer, start, @position)
  end

  private def handle_bracket : Token
    start = @position
    next_char
    case @current
    when ']'
      next_char
      Token.new("flatten", "[]", start, @position)
    when '?'
      next_char
      Token.new("filter", "[?", start, @position)
    else
      Token.new("lbracket", "[", start, @position)
    end
  end

  # Quoted identifiers ("..."): preserve all content verbatim including
  # backslash sequences so JSON.parse handles the escapes.
  private def consume_quoted_identifier : Token
    start = @position
    buffer = String.build do |str|
      next_char # skip opening "
      while @current != nil
        if @current == '\\' # preserve escape sequences verbatim for JSON.parse
          str << '\\'
          next_char
          str << (@current || "")
          next_char
        elsif @current == '"'
          break
        else
          str << @current
          next_char
        end
      end
      raise LexerError.new(@position, str.to_s, "Unclosed \" delimiter", @expression) if @current != '"'
    end
    next_char # skip closing "

    begin
      parsed_value = JSON.parse(%("#{buffer}"))
      value = parsed_value.as_s
      Token.new("quoted_identifier", value, start, @position)
    rescue ex : JSON::ParseException
      raise LexerError.new(start, buffer.to_s, "Invalid quoted identifier: #{ex.message}", @expression)
    end
  end

  # Raw string literals ('...'): only \' and \\ are escape sequences.
  # Everything else is literal, including other backslashes.
  private def consume_raw_string_literal : Token
    start = @position
    buffer = String.build do |str|
      next_char # skip opening '
      while @current != nil
        if @current == '\\' && peek_char == '\\'
          # \\ in raw string produces literal \\
          str << '\\'
          str << '\\'
          next_char
          next_char
        elsif @current == '\\' && peek_char == '\''
          # \' in raw string produces literal '
          next_char # skip backslash
          str << '\''
          next_char
        elsif @current == '\''
          break
        else
          str << @current
          next_char
        end
      end
      raise LexerError.new(@position, str.to_s, "Unclosed ' delimiter", @expression) if @current != '\''
    end
    next_char # skip closing '

    Token.new("literal", buffer.to_s, start, @position, JSON::Any.new(buffer.to_s))
  end

  # Backtick literals (`...`): only \` and \\ are escape sequences.
  # Everything else is passed verbatim to JSON.parse.
  private def consume_literal : Token
    start = @position
    buffer = String.build do |str|
      next_char # skip opening `
      while @current != nil
        if @current == '\\' && peek_char == '`'
          next_char # skip backslash
          str << '`'
          next_char
        elsif @current == '\\' && peek_char == '\\'
          next_char # skip first backslash
          str << '\\'
          next_char
        elsif @current == '`'
          break
        else
          str << @current
          next_char
        end
      end
      raise LexerError.new(@position, str.to_s, "Unclosed ` delimiter", @expression) if @current != '`'
    end
    next_char # skip closing `

    lexeme = buffer.to_s
    begin
      parsed_json = JSON.parse(lexeme)
      Token.new("literal", lexeme, start, @position, parsed_json)
    rescue ex : JSON::ParseException
      # JEP-12 deprecation: invalid JSON values are treated as quoted strings
      Token.new("literal", lexeme, start, @position, JSON::Any.new(lexeme))
    end
  end

  private def match_or_else(expected : Char, match_type : String, else_type : String) : Token
    start = @position
    value = @current.to_s
    nc = next_char
    if nc == expected
      next_char
      Token.new(match_type, "#{value}#{expected}", start, @position)
    else
      Token.new(else_type, value, start, start + 1)
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

  private def number : Token
    start = @position
    number_string = consume_number
    Token.new("number", number_string.to_i, start, @position)
  end

  private def negative_number : Token
    start = @position
    next_char
    if VALID_NUMBER.includes?(@current)
      number_string = "-" + consume_number
      Token.new("number", number_string.to_i32, start, @position)
    else
      raise LexerError.new(@position, @current.to_s, "Unknown token '-'", @expression)
    end
  end

  private def equal_sign : Token
    start = @position
    if next_char == '='
      next_char
      Token.new("eq", "==", start, @position)
    else
      position = @current.nil? ? @position : @position - 1
      raise LexerError.new(position, "=", "Unknown token '='", @expression)
    end
  end
end
