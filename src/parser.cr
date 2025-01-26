require "./lexer"
require "./exceptions"
require "./ast"

class Parser
  BINDING_POWER = {
    "eof"                 => 0,
    "unquoted_identifier" => 0,
    "quoted_identifier"   => 0,
    "literal"             => 0,
    "rbracket"            => 0,
    "rparen"              => 0,
    "comma"               => 0,
    "rbrace"              => 0,
    "number"              => 0,
    "current"             => 0,
    "expref"              => 0,
    "colon"               => 0,
    "pipe"                => 1,
    "or"                  => 2,
    "and"                 => 3,
    "eq"                  => 5,
    "gt"                  => 5,
    "lt"                  => 5,
    "gte"                 => 5,
    "lte"                 => 5,
    "ne"                  => 5,
    "flatten"             => 9,
    "star"                => 20,
    "filter"              => 21,
    "dot"                 => 40,
    "not"                 => 45,
    "lbrace"              => 50,
    "lbracket"            => 55,
    "lparen"              => 60,
  }
  PROJECTION_STOP =  10
  MAX_SIZE        = 128
  @cache = {} of String => ParsedResult

  def initialize(@lookahead : Int32 = 2)
    @tokens = [] of Token
    @index = 0
  end

  def parse(expression : String) : ParsedResult
    cached = @cache[expression]?
    return cached if cached

    parsed_result = do_parse(expression)
    @cache[expression] = parsed_result
    # free_cache_entries if @cache.size > MAX_SIZE
    parsed_result
  end

  private def do_parse(expression : String) : ParsedResult
    raise EmptyExpressionError.new if expression.empty?
    parsed = parse_expression(expression)
    parsed
  end

  private def parse_expression(expression : String) : ParsedResult
    lexer = Lexer.new
    @tokens = lexer.tokenize(expression)
    # iterate over the tokens and print them
    @tokens.each do |token|
      puts "token: #{token.type} - #{token.value}"
    end
    @index = 0
    parsed = parse_expression_bp(0)
    if @index < @tokens.size
      token = @tokens[@index]
      raise Exception.new("Unexpected token: #{token.type}")
    end
    ParsedResult.new(expression, parsed)
  end

  private def parse_expression_bp(min_bp : Int32) : ASTNode
    left = parse_null_denotation
    while @index < @tokens.size
      token = @tokens[@index]
      if BINDING_POWER[token.type] < min_bp
        break
      end
      @index += 1
      left = parse_left_denotation(left, token)
    end
    left
  end

  private def parse_left_denotation(left : ASTNode, token : Token) : ASTNode
    case token.type
    when "dot"
      right = parse_expression_bp(BINDING_POWER["dot"])
      ASTNode.new("subexpression", [left, right])
    when "eof"
      left
    else
      raise Exception.new("Unexpected token type: #{token.type}")
    end
  end

  private def parse_null_denotation : ASTNode
    token = advance
    # check the token type and return the appropriate ASTNode given the token type like _token_type(token)
    # lets start only with identifier and dot

    case token.type
    when "unquoted_identifier", "quoted_identifier"
      return identifier(token)
    when "literal"
      return literal(token)
    else
      raise Exception.new("Unexpected token type: #{token.type}")
    end
  end

  private def identifier(token : Token) : ASTNode
    puts "identifier: #{token.value}"
    ASTNode.new("identifier", [] of ASTNode, token.value)
  end

  private def literal(token : Token) : ASTNode
    ASTNode.new("literal", [] of ASTNode, token.value)
  end

  private def advance
    @index += 1
    @tokens[@index - 1]
  end

  private def lookahead_token(offset : Int32) : Token
    @tokens[@index + offset]
  end
end

class ParsedResult
  property parsed : ASTNode

  def initialize(@expression : String, @parsed : ASTNode)
  end

  def search(value : JSON::Any, options = nil)
    interpreter = TreeInterpreter.new(options)
    interpreter.visit(@parsed, value)
  end

  def render_dot_file : String
    renderer = GraphvizVisitor.new
    renderer.visit(@parsed)
  end

  def to_s
    @parsed.to_s
  end
end
