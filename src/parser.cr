require "./lexer"
require "./exceptions"
require "./ast"
require "./parsed_result"

class Parser
  @cache : Hash(String, ParsedResult)

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

  def initialize
    @tokens = [] of Token
    @index = 0
    @cache = {} of String => ParsedResult
  end

  def parse(expression : String) : ParsedResult
    cached = @cache[expression]?
    return cached if cached

    parsed_result = do_parse(expression)
    @cache[expression] = parsed_result
    parsed_result
  end

  private def do_parse(expression : String) : ParsedResult
    raise EmptyExpressionError.new if expression.empty?
    parse_expression(expression)
  end

  private def parse_expression(expression : String) : ParsedResult
    lexer = Lexer.new
    @tokens = lexer.tokenize(expression)
    @index = 0
    parsed = parse_expression_bp(0)

    # Only raise error if there are non-EOF tokens left
    if @index < @tokens.size && current_token.type != "eof"
      t = current_token
      raise ParseError.new(0, t.value.to_s, t.type, "Unexpected token: #{t.value}")
    end

    ParsedResult.new(expression, parsed)
  end

  private def parse_expression_bp(min_bp : Int32) : ASTNode
    left = parse_null_denotation
    while @index < @tokens.size
      token = current_token
      break if token.type == "eof" # Add explicit EOF check

      current_bp = BINDING_POWER[token.type]? || 0
      break if current_bp < min_bp

      @index += 1
      left = parse_left_denotation(left, token)
    end
    left
  end

  private def parse_null_denotation : ASTNode
    token = advance
    case token.type
    when "literal"             then literal(token.value)
    when "unquoted_identifier" then field(token.value)
    when "quoted_identifier"   then quoted_field(token)
    when "star"                then star_projection
    when "filter"              then filter_projection(identity)
    when "lbrace"              then parse_multi_select_hash
    when "lparen"              then parse_paren_expression
    when "flatten"             then flatten_projection
    when "current"             then current_node
    when "expref"              then expref_expression
    when "lbracket"            then parse_bracket_expression
    when "not"                 then not_expression
    else
      raise ParseError.new(0, token.value.to_s, token.type, "Unexpected token: #{token.type}")
    end
  end

  private def parse_left_denotation(left : ASTNode, token : Token) : ASTNode
    case token.type
    when "dot"  then parse_dot(left)
    when "pipe" then pipe_expression(left)
    when "or"   then or_expression(left)
    when "and"  then and_expression(left)
    when "eq", "ne", "gt", "lt", "gte", "lte"
      comparator_expression(left, token.type)
    when "flatten"  then flatten_projection(left)
    when "lbracket" then parse_bracket_operation(left)
    when "lparen"   then function_expression(left)
    when "filter"   then filter_projection(left)
    else
      raise ParseError.new(0, token.value.to_s, token.type, "Unexpected left token: #{token.type}")
    end
  end

  private def parse_dot(left : ASTNode) : ASTNode
    if lookahead(0) == "star"
      @index += 1
      right = parse_projection_rhs(BINDING_POWER["star"])
      value_projection(left, right)
    else
      right = parse_dot_rhs(BINDING_POWER["dot"])
      subexpression([left, right]) # Changed to pass array of nodes
    end
  end

  private def parse_dot_rhs(bp : Int32) : ASTNode
    case lookahead(0)
    when "unquoted_identifier", "quoted_identifier", "star"
      parse_expression_bp(bp)
    when "lbracket"
      @index += 1
      parse_multi_select_list
    when "lbrace"
      @index += 1
      parse_multi_select_hash
    else
      raise ParseError.new(0, current_token.value.to_s, current_token.type, "Invalid dot RHS")
    end
  end

  private def parse_bracket_expression : ASTNode
    if ["number", "colon"].includes?(lookahead(0))
      index_expression
    else
      parse_multi_select_list
    end
  end

  private def parse_bracket_operation(left : ASTNode) : ASTNode
    if ["number", "colon"].includes?(lookahead(0))
      right = index_expression
      project_if_slice(left, right)
    else
      @index += 1 # consume star
      @index += 1 # consume rbracket
      right = parse_projection_rhs(BINDING_POWER["star"])
      projection(left, right)
    end
  end

  private def project_if_slice(left : ASTNode, right : ASTNode) : ASTNode
    if right.type == "slice"
      projection(index_expression([left, right]), parse_projection_rhs(BINDING_POWER["star"]))
    else
      index_expression([left, right])
    end
  end

  private def index_expression(children = nil)
    children ||= begin
      if lookahead(0) == "colon"
        parse_slice
      else
        [index(current_token.value.as(Int32))].tap { @index += 1; match("rbracket") }
      end
    end
    ASTNode.new("index_expression", children)
  end

  private def parse_slice : Array(ASTNode)
    parts = [nil, nil, nil] of ASTNode?
    index = 0
    while current_token.type != "rbracket" && index < 3
      if current_token.type == "colon"
        index += 1
        @index += 1
      elsif current_token.type == "number"
        parts[index] = literal(current_token.value)
        @index += 1
      else
        raise ParseError.new(0, current_token.value.to_s, current_token.type, "Invalid slice")
      end
    end
    match("rbracket")
    parts.map { |p| p || literal(nil) }
  end

  private def parse_multi_select_list : ASTNode
    expressions = [] of ASTNode
    while current_token.type != "rbracket"
      expressions << parse_expression_bp(0)
      match("comma") if current_token.type == "comma"
    end
    match("rbracket")
    multi_select_list(expressions)
  end

  private def parse_multi_select_hash : ASTNode
    pairs = [] of ASTNode
    while current_token.type != "rbrace"
      key_token = current_token
      match(["quoted_identifier", "unquoted_identifier"])
      match("colon")
      value = parse_expression_bp(0)
      pairs << key_val_pair(key_token.value.to_s, value)
      match("comma") if current_token.type == "comma"
    end
    match("rbrace")
    multi_select_dict(pairs)
  end

  private def parse_projection_rhs(bp : Int32) : ASTNode
    if BINDING_POWER[current_token.type]? || 0 < PROJECTION_STOP
      identity
    else
      parse_expression_bp(bp)
    end
  end

  private def match(expected_types : String | Array(String))
    expected = expected_types.is_a?(String) ? [expected_types] : expected_types
    unless expected.includes?(current_token.type)
      raise ParseError.new(0, current_token.value.to_s, current_token.type,
        "Expected #{expected.join(" or ")}, got #{current_token.type}")
    end
    @index += 1 if current_token.type != "eof"
  end

  private def current_token : Token
    @tokens[@index]? || Token::NULL_TOKEN
  end

  private def lookahead(offset : Int32) : String
    @tokens[@index + offset]?.try(&.type) || "eof"
  end

  private def advance : Token
    token = current_token
    @index += 1 unless token.type == "eof"
    token
  end

  private def quoted_field(token : Token)
    raise "Not implemented: quoted_field"
  end

  private def star_projection
    raise "Not implemented: star_projection"
  end

  private def filter_projection(node : ASTNode)
    raise "Not implemented: filter_projection"
  end

  private def parse_paren_expression
    raise "Not implemented: parse_paren_expression"
  end

  private def flatten_projection
    raise "Not implemented: flatten_projection"
  end

  private def expref_expression
    raise "Not implemented: expref_expression"
  end

  private def not_expression
    raise "Not implemented: not_expression"
  end

  private def pipe_expression(left : ASTNode)
    raise "Not implemented: pipe_expression"
  end

  private def or_expression(left : ASTNode)
    raise "Not implemented: or_expression"
  end

  private def and_expression(left : ASTNode)
    raise "Not implemented: and_expression"
  end

  private def comparator_expression(left : ASTNode, comparator : String)
    raise "Not implemented: comparator_expression"
  end

  private def flatten_projection(left : ASTNode)
    raise "Not implemented: flatten_projection with argument"
  end

  private def function_expression(left : ASTNode)
    raise "Not implemented: function_expression"
  end
end
