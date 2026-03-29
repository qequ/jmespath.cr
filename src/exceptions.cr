class LexerError < Exception
  getter lexer_position : Int32
  getter lexer_value : String
  getter expression : String?

  def initialize(@lexer_position : Int32, @lexer_value : String, message : String, @expression : String? = nil)
    msg = String.build do |io|
      io << message
      if expr = @expression
        io << "\n" << expr << "\n"
        io << " " * @lexer_position << "^"
      end
    end
    super(msg)
  end
end

class ParseError < Exception
  getter lex_position : Int32
  getter token_value : String
  getter token_type : String
  getter expression : String?

  def initialize(@lex_position : Int32, @token_value : String, @token_type : String,
                 msg : String = "Invalid jmespath expression", @expression : String? = nil)
    full_msg = String.build do |io|
      io << msg
      io << " (at column #{@lex_position})"
      if expr = @expression
        io << "\n" << expr << "\n"
        io << " " * @lex_position << "^"
      end
    end
    super(full_msg)
  end
end

class EmptyExpressionError < Exception
  def initialize
    super("Invalid JMESPath expression: cannot be empty.")
  end
end

class UnknownFunctionError < Exception
  def initialize(name : String)
    super("Unknown function: #{name}()")
  end
end

class ArityError < Exception
  def initialize(name : String, expected : String, actual : Int32)
    super("Expected #{expected} argument(s) for function #{name}(), received #{actual}")
  end
end

class JMESPathTypeError < Exception
  def initialize(name : String, actual : String, expected : String)
    super("Invalid type for function #{name}(): expected #{expected}, got #{actual}")
  end
end
