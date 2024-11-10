class LexerError < Exception
  getter lexer_position : Int32
  getter lexer_value : String
  property expression : String?

  def initialize(@lexer_position : Int32, @lexer_value : String, message : String, @expression : String? = nil)
    super("#{message}: Bad jmespath expression at position #{lexer_position}\n#{expression}")
  end
end

class ParseError < Exception
  getter lex_position : Int32
  getter token_value : String
  getter token_type : String
  property expression : String?
  property msg : String = "Invalid jmespath expression"

  def initialize(@lex_position : Int32, @token_value : String, @token_type : String, msg : String = "Invalid jmespath expression")
    super("#{msg}: Parse error at column #{lex_position}, token \"#{token_value}\" (#{token_type}), for expression:\n\"#{expression}\"\n#{" " * (lex_position + 1)}^")
  end
end

class EmptyExpressionError < Exception
  def initialize
    super("Invalid JMESPath expression: cannot be empty.")
  end
end

class IncompleteExpressionError < ParseError
  def set_expression(expression : String)
    @expression = expression
    @lex_position = expression.size
    @token_type = ""
    @token_value = ""
  end

  def to_s : String
    underline = ' ' * (@lex_position + 1) + '^'
    "Invalid jmespath expression: Incomplete expression:\n" +
      "\"#{@expression}\"" + "\n" + underline
  end
end
