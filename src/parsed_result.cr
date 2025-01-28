require "./visitor"

class ParsedResult
  property expression : String
  property parsed : ASTNode

  def initialize(@expression : String, @parsed : ASTNode)
  end

  def search(value : JSON::Any, options = nil) : JSON::Any
    interpreter = TreeInterpreter.new(options)
    interpreter.visit(@parsed, value)
  end

  def to_s(io : IO) : Nil
    io << @parsed.to_s
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end
end
