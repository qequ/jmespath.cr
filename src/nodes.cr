require "json"
require "./functions"

# Base class for all AST nodes. Each node implements visit(value)
# directly, using polymorphism instead of a central visitor dispatcher.
abstract class Node
  abstract def visit(v : JSON::Any) : JSON::Any

  # Introspection methods for testing/debugging
  def type : String
    "unknown"
  end

  def value : Char | Int32 | String | Nil
    nil
  end

  def children : Array(Node)
    [] of Node
  end

  protected def is_true(value : JSON::Any) : Bool
    !is_false(value)
  end

  protected def is_false(value : JSON::Any) : Bool
    case raw = value.raw
    when Nil    then true
    when String then raw.empty?
    when Array  then raw.empty?
    when Hash   then raw.empty?
    when Bool   then !raw
    else             false
    end
  end
end

class FieldNode < Node
  def initialize(@key : String)
  end

  def visit(v : JSON::Any) : JSON::Any
    if v.as_h?.try(&.has_key?(@key))
      v[@key]
    else
      JSON::Any.new(nil)
    end
  end

  def type : String
    "field"
  end

  def value : Char | Int32 | String | Nil
    @key
  end
end

class LiteralNode < Node
  def initialize(@literal : JSON::Any)
  end

  def visit(v : JSON::Any) : JSON::Any
    @literal
  end

  def type : String
    "literal"
  end

  def value : Char | Int32 | String | Nil
    case raw = @literal.raw
    when Int64  then raw.to_i32
    when String then raw
    else             nil
    end
  end
end

class IdentityNode < Node
  def visit(v : JSON::Any) : JSON::Any
    v
  end

  def type : String
    "identity"
  end
end

class CurrentNode < Node
  def visit(v : JSON::Any) : JSON::Any
    v
  end

  def type : String
    "current"
  end
end

class IndexNode < Node
  def initialize(@index : Int32)
  end

  def visit(v : JSON::Any) : JSON::Any
    array = v.as_a?
    return JSON::Any.new(nil) unless array
    begin
      array[@index]
    rescue IndexError
      JSON::Any.new(nil)
    end
  end

  def type : String
    "index"
  end

  def value : Char | Int32 | String | Nil
    @index
  end
end

class SubexpressionNode < Node
  def initialize(@left : Node, @right : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    @right.visit(@left.visit(v))
  end

  def type : String
    "subexpression"
  end

  def children : Array(Node)
    [@left, @right]
  end
end

class PipeNode < Node
  def initialize(@left : Node, @right : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    @right.visit(@left.visit(v))
  end

  def type : String
    "pipe"
  end

  def children : Array(Node)
    [@left, @right]
  end
end

class OrExpressionNode < Node
  def initialize(@left : Node, @right : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    left = @left.visit(v)
    return left unless is_false(left)
    @right.visit(v)
  end

  def type : String
    "or_expression"
  end

  def children : Array(Node)
    [@left, @right]
  end
end

class AndExpressionNode < Node
  def initialize(@left : Node, @right : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    left = @left.visit(v)
    return JSON::Any.new(nil) if is_false(left)
    @right.visit(v)
  end

  def type : String
    "and_expression"
  end

  def children : Array(Node)
    [@left, @right]
  end
end

class NotExpressionNode < Node
  def initialize(@expression : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    result = @expression.visit(v)
    JSON::Any.new(is_false(result))
  end

  def type : String
    "not_expression"
  end

  def children : Array(Node)
    [@expression]
  end
end

class ComparatorNode < Node
  def initialize(@comparator : String, @left : Node, @right : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    left = @left.visit(v)
    right = @right.visit(v)

    result = case @comparator
             when "eq" then equals(left, right)
             when "ne" then !equals(left, right)
             else
               if number?(left) && number?(right)
                 lf = to_float(left)
                 rf = to_float(right)
                 case @comparator
                 when "lt"  then lf < rf
                 when "gt"  then lf > rf
                 when "lte" then lf <= rf
                 when "gte" then lf >= rf
                 else            false
                 end
               else
                 false
               end
             end

    JSON::Any.new(result)
  end

  def type : String
    "comparator"
  end

  def value : Char | Int32 | String | Nil
    @comparator
  end

  def children : Array(Node)
    [@left, @right]
  end

  private def equals(a : JSON::Any, b : JSON::Any) : Bool
    a.raw == b.raw
  end

  private def number?(v : JSON::Any) : Bool
    v.raw.is_a?(Int64) || v.raw.is_a?(Float64)
  end

  private def to_float(v : JSON::Any) : Float64
    case raw = v.raw
    when Int64   then raw.to_f64
    when Float64 then raw
    else              0.0
    end
  end
end

class ProjectionNode < Node
  def initialize(@left : Node, @right : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    base = @left.visit(v)
    array = base.as_a?
    return JSON::Any.new(nil) unless array

    collected = array.compact_map do |element|
      result = @right.visit(element)
      result unless result.raw.nil?
    end
    JSON::Any.new(collected)
  end

  def type : String
    "projection"
  end

  def children : Array(Node)
    [@left, @right]
  end
end

class ValueProjectionNode < Node
  def initialize(@left : Node, @right : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    base = @left.visit(v)
    hash = base.as_h?
    return JSON::Any.new(nil) unless hash

    collected = hash.values.compact_map do |element|
      result = @right.visit(element)
      result unless result.raw.nil?
    end
    JSON::Any.new(collected)
  end

  def type : String
    "value_projection"
  end

  def children : Array(Node)
    [@left, @right]
  end
end

class FilterProjectionNode < Node
  def initialize(@left : Node, @right : Node, @condition : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    base = @left.visit(v)
    array = base.as_a?
    return JSON::Any.new(nil) unless array

    collected = array.compact_map do |element|
      if is_true(@condition.visit(element))
        result = @right.visit(element)
        result unless result.raw.nil?
      end
    end
    JSON::Any.new(collected)
  end

  def type : String
    "filter_projection"
  end

  def children : Array(Node)
    [@left, @right, @condition]
  end
end

class FlattenNode < Node
  def initialize(@child : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    base = @child.visit(v)
    array = base.as_a?
    return JSON::Any.new([] of JSON::Any) unless array

    merged = [] of JSON::Any
    array.each do |element|
      if elem_array = element.as_a?
        merged.concat(elem_array)
      else
        merged << element
      end
    end
    JSON::Any.new(merged)
  end

  def type : String
    "flatten"
  end

  def children : Array(Node)
    [@child]
  end
end

class IndexExpressionNode < Node
  def initialize(@nodes : Array(Node))
  end

  def visit(v : JSON::Any) : JSON::Any
    result = v
    @nodes.each do |node|
      result = node.visit(result)
    end
    result
  end

  def type : String
    "index_expression"
  end

  def children : Array(Node)
    @nodes
  end
end

class SliceNode < Node
  def initialize(@start : Int32?, @stop : Int32?, @step : Int32?)
  end

  def visit(v : JSON::Any) : JSON::Any
    array = v.as_a?
    return JSON::Any.new(nil) unless array

    len = array.size
    step = @step || 1
    return JSON::Any.new([] of JSON::Any) if step == 0

    start_idx = compute_start(len, step)
    stop_idx = compute_stop(len, step)

    result = [] of JSON::Any
    i = start_idx
    if step > 0
      while i < stop_idx
        result << array[i] if i >= 0 && i < len
        i += step
      end
    else
      while i > stop_idx
        result << array[i] if i >= 0 && i < len
        i += step
      end
    end
    JSON::Any.new(result)
  end

  def type : String
    "slice"
  end

  private def compute_start(len : Int32, step : Int32) : Int32
    if s = @start
      s < 0 ? {len + s, 0}.max : {s, len}.min
    elsif step > 0
      0
    else
      len - 1
    end
  end

  private def compute_stop(len : Int32, step : Int32) : Int32
    if s = @stop
      if step > 0
        s < 0 ? {len + s, 0}.max : {s, len}.min
      else
        s < 0 ? {len + s, -1}.max : {s, len - 1}.min
      end
    elsif step > 0
      len
    else
      -1
    end
  end
end

class KeyValPairNode < Node
  getter key : String

  def initialize(@key : String, @value_node : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    @value_node.visit(v)
  end

  def type : String
    "key_val_pair"
  end

  def value : Char | Int32 | String | Nil
    @key
  end

  def children : Array(Node)
    [@value_node]
  end
end

class MultiSelectHashNode < Node
  def initialize(@pairs : Array(KeyValPairNode))
  end

  def visit(v : JSON::Any) : JSON::Any
    return JSON::Any.new(nil) if v.raw.nil?
    collected = {} of String => JSON::Any
    @pairs.each do |pair|
      collected[pair.key] = pair.visit(v)
    end
    JSON::Any.new(collected)
  end

  def type : String
    "multi_select_dict"
  end

  def children : Array(Node)
    @pairs.map { |p| p.as(Node) }
  end
end

class MultiSelectListNode < Node
  def initialize(@nodes : Array(Node))
  end

  def visit(v : JSON::Any) : JSON::Any
    return JSON::Any.new(nil) if v.raw.nil?
    collected = @nodes.map do |node|
      node.visit(v)
    end
    JSON::Any.new(collected)
  end

  def type : String
    "multi_select_list"
  end

  def children : Array(Node)
    @nodes
  end
end

class FunctionExpressionNode < Node
  def initialize(@name : String, @args : Array(Node))
  end

  def visit(v : JSON::Any) : JSON::Any
    FunctionRuntime.invoke(@name, @args, v)
  end

  def type : String
    "function_expression"
  end

  def value : Char | Int32 | String | Nil
    @name
  end

  def children : Array(Node)
    @args
  end
end

class ExprefNode < Node
  getter expression : Node

  def initialize(@expression : Node)
  end

  def visit(v : JSON::Any) : JSON::Any
    # Expression references are evaluated by FunctionRuntime,
    # not visited directly. Return nil if used outside a function.
    JSON::Any.new(nil)
  end

  def type : String
    "expref"
  end

  def children : Array(Node)
    [@expression]
  end
end
