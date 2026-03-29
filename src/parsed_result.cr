require "./nodes"

class ParsedResult
  property expression : String
  property parsed : Node

  def initialize(@expression : String, @parsed : Node)
  end

  def search(value : JSON::Any, options = nil) : JSON::Any
    @parsed.visit(value)
  end

  def to_s(io : IO) : Nil
    io << @parsed.to_s
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end
end
