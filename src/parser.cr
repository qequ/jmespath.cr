require "./lexer"
require "./exceptions"
require "./nodes"
require "./parsed_result"

class Parser
  @cache : Hash(String, ParsedResult)
  @expression : String = ""

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
    @expression = expression
    lexer = Lexer.new
    @tokens = lexer.tokenize(expression)
    @index = 0
    parsed = parse_expression_bp(0)

    if @index < @tokens.size && current_token.type != "eof"
      t = current_token
      raise parse_error(t, "Unexpected token after expression: #{t.value}")
    end

    ParsedResult.new(expression, parsed)
  end

  private def parse_expression_bp(min_bp : Int32) : Node
    left = parse_null_denotation
    while @index < @tokens.size
      token = current_token
      break if token.type == "eof"

      current_bp = BINDING_POWER[token.type]? || 0
      break if current_bp <= min_bp
      @index += 1
      left = parse_left_denotation(left, token)
    end
    left
  end

  private def parse_null_denotation : Node
    token = advance
    case token.type
    when "literal"
      LiteralNode.new(token.json_value || JSON::Any.new(nil))
    when "unquoted_identifier"
      FieldNode.new(token.value.to_s)
    when "quoted_identifier"
      parse_quoted_field(token)
    when "star"
      parse_star_projection
    when "filter"
      parse_nud_filter_projection
    when "lbrace"
      parse_multi_select_hash
    when "lparen"
      parse_paren_expression
    when "flatten"
      parse_nud_flatten_projection
    when "current"
      CurrentNode.new
    when "expref"
      parse_expref_expression
    when "lbracket"
      parse_bracket_expression
    when "not"
      parse_not_expression
    else
      raise parse_error(token, "Unexpected token: #{token.type}")
    end
  end

  private def parse_left_denotation(left : Node, token : Token) : Node
    case token.type
    when "dot"  then parse_dot(left)
    when "pipe" then parse_pipe_expression(left)
    when "or"   then parse_or_expression(left)
    when "and"  then parse_and_expression(left)
    when "eq", "ne", "gt", "lt", "gte", "lte"
      parse_comparator_expression(left, token.type)
    when "flatten"  then parse_led_flatten_projection(left)
    when "lbracket" then parse_bracket_operation(left)
    when "lparen"   then parse_function_expression(left)
    when "filter"   then parse_led_filter_projection(left)
    else
      raise parse_error(token, "Unexpected token: #{token.type}")
    end
  end

  private def parse_dot(left : Node) : Node
    if lookahead(0) == "star"
      @index += 1
      right = parse_projection_rhs(BINDING_POWER["star"])
      ValueProjectionNode.new(left, right)
    else
      right = parse_dot_rhs(BINDING_POWER["dot"])
      SubexpressionNode.new(left, right)
    end
  end

  private def parse_dot_rhs(bp : Int32) : Node
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
      raise parse_error(current_token, "Expected identifier, star, bracket, or brace after dot")
    end
  end

  private def parse_bracket_expression : Node
    if ["number", "colon"].includes?(lookahead(0))
      IndexExpressionNode.new([parse_index_expression])
    elsif lookahead(0) == "star" && lookahead(1) == "rbracket"
      advance # consume 'star'
      advance # consume 'rbracket'
      right = parse_projection_rhs(BINDING_POWER["star"])
      ProjectionNode.new(IdentityNode.new, right)
    else
      parse_multi_select_list
    end
  end

  private def parse_index_expression : Node
    if lookahead(0) == "colon" || lookahead(1) == "colon"
      parse_slice
    else
      index_token = current_token
      match("number")
      index_value = index_token.value.as(Int32)
      match("rbracket")
      IndexNode.new(index_value)
    end
  end

  private def parse_bracket_operation(left : Node) : Node
    if ["number", "colon"].includes?(lookahead(0))
      right = parse_index_expression
      if right.type == "slice"
        ProjectionNode.new(
          IndexExpressionNode.new([left, right]),
          IdentityNode.new
        )
      else
        IndexExpressionNode.new([left, right])
      end
    elsif current_token.type == "star"
      @index += 1 # consume star
      match("rbracket")
      right = parse_projection_rhs(BINDING_POWER["star"])
      ProjectionNode.new(left, right)
    else
      raise parse_error(current_token, "Expected number, colon, or star in bracket expression")
    end
  end

  private def parse_slice : Node
    parts = [nil, nil, nil] of Int32?
    index = 0

    while current_token.type != "rbracket" && index < 3
      if current_token.type == "colon"
        index += 1
        @index += 1
      elsif current_token.type == "number"
        parts[index] = current_token.value.as(Int32)
        @index += 1
      else
        raise parse_error(current_token, "Expected number or colon in slice expression")
      end
    end
    match("rbracket")

    SliceNode.new(parts[0], parts[1], parts[2])
  end

  private def parse_multi_select_list : Node
    expressions = [] of Node
    while current_token.type != "rbracket"
      expressions << parse_expression_bp(0)
      match("comma") if current_token.type == "comma"
    end
    match("rbracket")
    MultiSelectListNode.new(expressions)
  end

  private def parse_multi_select_hash : Node
    pairs = [] of KeyValPairNode
    while current_token.type != "rbrace"
      key_token = current_token
      match(["quoted_identifier", "unquoted_identifier"])
      match("colon")
      value = parse_expression_bp(0)
      pairs << KeyValPairNode.new(key_token.value.to_s, value)
      match("comma") if current_token.type == "comma"
    end
    match("rbrace")
    MultiSelectHashNode.new(pairs)
  end

  private def parse_projection_rhs(bp : Int32) : Node
    if (BINDING_POWER[current_token.type]? || 0) < PROJECTION_STOP
      return IdentityNode.new
    end

    case current_token.type
    when "lbracket"
      parse_expression_bp(bp)
    when "filter"
      parse_expression_bp(bp)
    when "dot"
      advance # consume the 'dot'
      parse_dot_rhs(bp)
    else
      raise parse_error(current_token, "Expected dot, bracket, or filter after projection")
    end
  end

  private def match(expected_types : String | Array(String))
    expected = expected_types.is_a?(String) ? [expected_types] : expected_types
    unless expected.includes?(current_token.type)
      raise parse_error(current_token,
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

  private def parse_quoted_field(token : Token) : Node
    field_node = FieldNode.new(token.value.to_s)

    if current_token.type == "lparen"
      raise parse_error(token, "Quoted identifier not allowed for function names.")
    end

    field_node
  end

  private def parse_star_projection : Node
    left = IdentityNode.new
    right = if current_token.type == "rbracket"
              IdentityNode.new
            else
              parse_projection_rhs(BINDING_POWER["star"])
            end
    ValueProjectionNode.new(left, right)
  end

  private def parse_nud_filter_projection : Node
    parse_led_filter_projection(IdentityNode.new)
  end

  private def parse_led_filter_projection(left : Node) : Node
    condition = parse_expression_bp(0)
    match("rbracket")

    right = if current_token.type == "flatten"
              IdentityNode.new
            else
              parse_projection_rhs(BINDING_POWER["filter"])
            end

    FilterProjectionNode.new(left, right, condition)
  end

  private def parse_paren_expression : Node
    expr = parse_expression_bp(0)
    match("rparen")
    expr
  end

  private def parse_nud_flatten_projection : Node
    flatten_node = FlattenNode.new(IdentityNode.new)
    right = parse_projection_rhs(BINDING_POWER["flatten"])
    ProjectionNode.new(flatten_node, right)
  end

  private def parse_expref_expression : Node
    expr = parse_expression_bp(BINDING_POWER["expref"])
    ExprefNode.new(expr)
  end

  private def parse_not_expression : Node
    expr = parse_expression_bp(BINDING_POWER["not"])
    NotExpressionNode.new(expr)
  end

  private def parse_pipe_expression(left : Node) : Node
    right = parse_expression_bp(BINDING_POWER["pipe"])
    PipeNode.new(left, right)
  end

  private def parse_or_expression(left : Node) : Node
    right = parse_expression_bp(BINDING_POWER["or"])
    OrExpressionNode.new(left, right)
  end

  private def parse_and_expression(left : Node) : Node
    right = parse_expression_bp(BINDING_POWER["and"])
    AndExpressionNode.new(left, right)
  end

  private def parse_comparator_expression(left : Node, comparator : String) : Node
    right = parse_expression_bp(BINDING_POWER[comparator])
    ComparatorNode.new(comparator, left, right)
  end

  private def parse_led_flatten_projection(left : Node) : Node
    flatten_node = FlattenNode.new(left)
    right = parse_projection_rhs(BINDING_POWER["flatten"])
    ProjectionNode.new(flatten_node, right)
  end

  private def parse_function_expression(left : Node) : Node
    unless left.type == "field"
      prev_token = @tokens[@index - 2]?
      raise parse_error(prev_token || current_token,
        "Invalid function name '#{prev_token.try(&.value)}'")
    end

    name = left.value.to_s
    args = [] of Node

    while current_token.type != "rparen"
      expression = parse_expression_bp(0)
      match("comma") if current_token.type == "comma"
      args << expression
    end

    match("rparen")

    FunctionExpressionNode.new(name, args)
  end

  # Extracts the start position from a token as Int32
  private def token_position(token : Token) : Int32
    case pos = token.start
    when Int32 then pos
    else            0
    end
  end

  # Creates a ParseError with the correct position and expression context
  private def parse_error(token : Token, msg : String) : ParseError
    ParseError.new(token_position(token), token.value.to_s, token.type, msg, @expression)
  end
end
