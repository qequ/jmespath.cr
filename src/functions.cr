require "json"
require "./exceptions"

class FunctionRuntime
  ARITY = {
    "abs"         => {1, 1},
    "avg"         => {1, 1},
    "ceil"        => {1, 1},
    "contains"    => {2, 2},
    "ends_with"   => {2, 2},
    "floor"       => {1, 1},
    "join"        => {2, 2},
    "keys"        => {1, 1},
    "length"      => {1, 1},
    "map"         => {2, 2},
    "max"         => {1, 1},
    "max_by"      => {2, 2},
    "merge"       => {1, -1},
    "min"         => {1, 1},
    "min_by"      => {2, 2},
    "not_null"    => {1, -1},
    "reverse"     => {1, 1},
    "sort"        => {1, 1},
    "sort_by"     => {2, 2},
    "starts_with" => {2, 2},
    "sum"         => {1, 1},
    "to_array"    => {1, 1},
    "to_number"   => {1, 1},
    "to_string"   => {1, 1},
    "type"        => {1, 1},
    "values"      => {1, 1},
  }

  def self.invoke(name : String, args : Array(Node), current : JSON::Any) : JSON::Any
    unless ARITY.has_key?(name)
      raise UnknownFunctionError.new(name)
    end

    validate_arity(name, args.size)

    case name
    when "abs"         then func_abs(eval(args, 0, current))
    when "avg"         then func_avg(eval(args, 0, current))
    when "ceil"        then func_ceil(eval(args, 0, current))
    when "contains"    then func_contains(eval(args, 0, current), eval(args, 1, current))
    when "ends_with"   then func_ends_with(eval(args, 0, current), eval(args, 1, current))
    when "floor"       then func_floor(eval(args, 0, current))
    when "join"        then func_join(eval(args, 0, current), eval(args, 1, current))
    when "keys"        then func_keys(eval(args, 0, current))
    when "length"      then func_length(eval(args, 0, current))
    when "map"         then func_map(expref(args, 0), eval(args, 1, current))
    when "max"         then func_max(eval(args, 0, current))
    when "max_by"      then func_max_by(eval(args, 0, current), expref(args, 1))
    when "merge"       then func_merge(eval_all(args, current))
    when "min"         then func_min(eval(args, 0, current))
    when "min_by"      then func_min_by(eval(args, 0, current), expref(args, 1))
    when "not_null"    then func_not_null(eval_all(args, current))
    when "reverse"     then func_reverse(eval(args, 0, current))
    when "sort"        then func_sort(eval(args, 0, current))
    when "sort_by"     then func_sort_by(eval(args, 0, current), expref(args, 1))
    when "starts_with" then func_starts_with(eval(args, 0, current), eval(args, 1, current))
    when "sum"         then func_sum(eval(args, 0, current))
    when "to_array"    then func_to_array(eval(args, 0, current))
    when "to_number"   then func_to_number(eval(args, 0, current))
    when "to_string"   then func_to_string(eval(args, 0, current))
    when "type"        then func_type(eval(args, 0, current))
    when "values"      then func_values(eval(args, 0, current))
    else
      raise UnknownFunctionError.new(name)
    end
  end

  # -- Argument helpers --

  private def self.eval(args : Array(Node), index : Int32, current : JSON::Any) : JSON::Any
    args[index].visit(current)
  end

  private def self.expref(args : Array(Node), index : Int32) : Node
    node = args[index]
    if expref_node = node.as?(ExprefNode)
      expref_node.expression
    else
      raise JMESPathTypeError.new("argument #{index}", jmespath_type(node.visit(JSON::Any.new(nil))), "expref")
    end
  end

  private def self.eval_all(args : Array(Node), current : JSON::Any) : Array(JSON::Any)
    args.map { |arg| arg.visit(current) }
  end

  private def self.validate_arity(name : String, actual : Int32)
    min, max = ARITY[name]
    if actual < min
      raise ArityError.new(name, "at least #{min}", actual)
    end
    if max != -1 && actual > max
      raise ArityError.new(name, "at most #{max}", actual)
    end
  end

  # -- Number functions --

  private def self.func_abs(v : JSON::Any) : JSON::Any
    case raw = v.raw
    when Int64   then JSON::Any.new(raw.abs)
    when Float64 then JSON::Any.new(raw.abs)
    else              raise_type_error("abs", v, "number")
    end
  end

  private def self.func_avg(v : JSON::Any) : JSON::Any
    arr = require_array("avg", v)
    return JSON::Any.new(nil) if arr.empty?
    sum = arr.sum { |e| require_number("avg", e) }
    JSON::Any.new(sum / arr.size)
  end

  private def self.func_ceil(v : JSON::Any) : JSON::Any
    case raw = v.raw
    when Int64   then JSON::Any.new(raw)
    when Float64 then JSON::Any.new(raw.ceil.to_i64)
    else              raise_type_error("ceil", v, "number")
    end
  end

  private def self.func_floor(v : JSON::Any) : JSON::Any
    case raw = v.raw
    when Int64   then JSON::Any.new(raw)
    when Float64 then JSON::Any.new(raw.floor.to_i64)
    else              raise_type_error("floor", v, "number")
    end
  end

  private def self.func_sum(v : JSON::Any) : JSON::Any
    arr = require_array("sum", v)
    return JSON::Any.new(0_i64) if arr.empty?
    if arr.all? { |e| e.raw.is_a?(Int64) }
      JSON::Any.new(arr.sum { |e| e.as_i64 })
    else
      JSON::Any.new(arr.sum { |e| require_number("sum", e) })
    end
  end

  # -- String / array functions --

  private def self.func_length(v : JSON::Any) : JSON::Any
    case raw = v.raw
    when String then JSON::Any.new(raw.size.to_i64)
    when Array  then JSON::Any.new(raw.size.to_i64)
    when Hash   then JSON::Any.new(raw.size.to_i64)
    else             raise_type_error("length", v, "string, array, or object")
    end
  end

  private def self.func_reverse(v : JSON::Any) : JSON::Any
    case raw = v.raw
    when String then JSON::Any.new(raw.reverse)
    when Array  then JSON::Any.new(raw.reverse)
    else             raise_type_error("reverse", v, "string or array")
    end
  end

  private def self.func_sort(v : JSON::Any) : JSON::Any
    arr = require_array("sort", v)
    return JSON::Any.new(arr) if arr.empty?

    if arr.all? { |e| e.raw.is_a?(String) }
      JSON::Any.new(arr.sort_by { |e| e.as_s })
    elsif arr.all? { |e| e.raw.is_a?(Int64) || e.raw.is_a?(Float64) }
      JSON::Any.new(arr.sort_by { |e| to_f64(e) })
    else
      raise_type_error("sort", v, "array of strings or array of numbers")
    end
  end

  private def self.func_join(glue : JSON::Any, arr : JSON::Any) : JSON::Any
    g = glue.as_s? || raise_type_error("join", glue, "string")
    a = require_array("join", arr)
    strings = a.map { |e| e.as_s? || raise_type_error("join", e, "string") }
    JSON::Any.new(strings.join(g))
  end

  private def self.func_contains(subject : JSON::Any, search : JSON::Any) : JSON::Any
    case raw = subject.raw
    when String
      search_str = search.as_s?
      return JSON::Any.new(false) unless search_str
      JSON::Any.new(raw.includes?(search_str))
    when Array
      JSON::Any.new(raw.any? { |e| e.raw == search.raw })
    else
      raise_type_error("contains", subject, "string or array")
    end
  end

  private def self.func_starts_with(str : JSON::Any, prefix : JSON::Any) : JSON::Any
    s = str.as_s? || raise_type_error("starts_with", str, "string")
    p = prefix.as_s? || raise_type_error("starts_with", prefix, "string")
    JSON::Any.new(s.starts_with?(p))
  end

  private def self.func_ends_with(str : JSON::Any, suffix : JSON::Any) : JSON::Any
    s = str.as_s? || raise_type_error("ends_with", str, "string")
    sf = suffix.as_s? || raise_type_error("ends_with", suffix, "string")
    JSON::Any.new(s.ends_with?(sf))
  end

  # -- Object functions --

  private def self.func_keys(v : JSON::Any) : JSON::Any
    hash = v.as_h? || raise_type_error("keys", v, "object")
    JSON::Any.new(hash.keys.map { |k| JSON::Any.new(k) })
  end

  private def self.func_values(v : JSON::Any) : JSON::Any
    hash = v.as_h? || raise_type_error("values", v, "object")
    JSON::Any.new(hash.values)
  end

  private def self.func_merge(args : Array(JSON::Any)) : JSON::Any
    result = {} of String => JSON::Any
    args.each do |arg|
      hash = arg.as_h? || raise_type_error("merge", arg, "object")
      result.merge!(hash)
    end
    JSON::Any.new(result)
  end

  # -- Conversion functions --

  private def self.func_type(v : JSON::Any) : JSON::Any
    JSON::Any.new(jmespath_type(v))
  end

  private def self.func_to_array(v : JSON::Any) : JSON::Any
    if v.as_a?
      v
    else
      JSON::Any.new([v])
    end
  end

  private def self.func_to_string(v : JSON::Any) : JSON::Any
    if v.as_s?
      v
    else
      JSON::Any.new(v.to_json)
    end
  end

  private def self.func_to_number(v : JSON::Any) : JSON::Any
    case raw = v.raw
    when Int64, Float64
      v
    when String
      begin
        if raw.includes?(".")
          JSON::Any.new(raw.to_f64)
        else
          JSON::Any.new(raw.to_i64)
        end
      rescue
        JSON::Any.new(nil)
      end
    else
      JSON::Any.new(nil)
    end
  end

  # -- Min / max functions --

  private def self.func_max(v : JSON::Any) : JSON::Any
    arr = require_array("max", v)
    return JSON::Any.new(nil) if arr.empty?

    if arr.all? { |e| e.raw.is_a?(String) }
      arr.max_by { |e| e.as_s }
    elsif arr.all? { |e| e.raw.is_a?(Int64) || e.raw.is_a?(Float64) }
      arr.max_by { |e| to_f64(e) }
    else
      raise_type_error("max", v, "array of strings or array of numbers")
    end
  end

  private def self.func_min(v : JSON::Any) : JSON::Any
    arr = require_array("min", v)
    return JSON::Any.new(nil) if arr.empty?

    if arr.all? { |e| e.raw.is_a?(String) }
      arr.min_by { |e| e.as_s }
    elsif arr.all? { |e| e.raw.is_a?(Int64) || e.raw.is_a?(Float64) }
      arr.min_by { |e| to_f64(e) }
    else
      raise_type_error("min", v, "array of strings or array of numbers")
    end
  end

  private def self.func_not_null(args : Array(JSON::Any)) : JSON::Any
    args.each do |arg|
      return arg unless arg.raw.nil?
    end
    JSON::Any.new(nil)
  end

  # -- Expref functions --

  private def self.func_map(expr : Node, arr : JSON::Any) : JSON::Any
    a = require_array("map", arr)
    result = a.map { |element| expr.visit(element) }
    JSON::Any.new(result)
  end

  private def self.func_sort_by(arr : JSON::Any, expr : Node) : JSON::Any
    a = require_array("sort_by", arr)
    return JSON::Any.new(a) if a.empty?

    # Determine sort type from first element
    first_key = expr.visit(a[0])
    if first_key.raw.is_a?(String)
      JSON::Any.new(a.sort_by { |e| expr.visit(e).as_s })
    elsif first_key.raw.is_a?(Int64) || first_key.raw.is_a?(Float64)
      JSON::Any.new(a.sort_by { |e| to_f64(expr.visit(e)) })
    else
      raise_type_error("sort_by", first_key, "number or string")
    end
  end

  private def self.func_max_by(arr : JSON::Any, expr : Node) : JSON::Any
    a = require_array("max_by", arr)
    return JSON::Any.new(nil) if a.empty?

    first_key = expr.visit(a[0])
    if first_key.raw.is_a?(String)
      a.max_by { |e| expr.visit(e).as_s }
    elsif first_key.raw.is_a?(Int64) || first_key.raw.is_a?(Float64)
      a.max_by { |e| to_f64(expr.visit(e)) }
    else
      raise_type_error("max_by", first_key, "number or string")
    end
  end

  private def self.func_min_by(arr : JSON::Any, expr : Node) : JSON::Any
    a = require_array("min_by", arr)
    return JSON::Any.new(nil) if a.empty?

    first_key = expr.visit(a[0])
    if first_key.raw.is_a?(String)
      a.min_by { |e| expr.visit(e).as_s }
    elsif first_key.raw.is_a?(Int64) || first_key.raw.is_a?(Float64)
      a.min_by { |e| to_f64(expr.visit(e)) }
    else
      raise_type_error("min_by", first_key, "number or string")
    end
  end

  # -- Helpers --

  private def self.to_f64(v : JSON::Any) : Float64
    case raw = v.raw
    when Int64   then raw.to_f64
    when Float64 then raw
    else              0.0
    end
  end

  private def self.require_number(func : String, v : JSON::Any) : Float64
    case raw = v.raw
    when Int64   then raw.to_f64
    when Float64 then raw
    else              raise_type_error(func, v, "number")
    end
  end

  private def self.require_array(func : String, v : JSON::Any) : Array(JSON::Any)
    v.as_a? || raise_type_error(func, v, "array")
  end

  private def self.jmespath_type(v : JSON::Any) : String
    case v.raw
    when Nil     then "null"
    when Bool    then "boolean"
    when Int64   then "number"
    when Float64 then "number"
    when String  then "string"
    when Array   then "array"
    when Hash    then "object"
    else              "unknown"
    end
  end

  private def self.raise_type_error(func : String, v : JSON::Any, expected : String) : NoReturn
    raise JMESPathTypeError.new(func, jmespath_type(v), expected)
  end
end
