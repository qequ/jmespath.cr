# visitor.cr
abstract class Visitor
  def visit(node : ASTNode, value : JSON::Any) : JSON::Any
    case node.type
    when "subexpression"       then visit_subexpression(node, value)
    when "field"               then visit_field(node, value)
    when "comparator"          then visit_comparator(node, value)
    when "current"             then visit_current(node, value)
    when "expref"              then visit_expref(node, value)
    when "function_expression" then visit_function_expression(node, value)
    when "filter_projection"   then visit_filter_projection(node, value)
    when "flatten"             then visit_flatten(node, value)
    when "identity"            then visit_identity(node, value)
    when "index"               then visit_index(node, value)
    when "index_expression"    then visit_index_expression(node, value)
    when "slice"               then visit_slice(node, value)
    when "key_val_pair"        then visit_key_val_pair(node, value)
    when "literal"             then visit_literal(node, value)
    when "multi_select_dict"   then visit_multi_select_dict(node, value)
    when "multi_select_list"   then visit_multi_select_list(node, value)
    when "or_expression"       then visit_or_expression(node, value)
    when "and_expression"      then visit_and_expression(node, value)
    when "not_expression"      then visit_not_expression(node, value)
    when "pipe"                then visit_pipe(node, value)
    when "projection"          then visit_projection(node, value)
    when "value_projection"    then visit_value_projection(node, value)
    else
      default_visit(node, value)
    end
  end

  abstract def default_visit(node : ASTNode, value : JSON::Any) : JSON::Any
end

class TreeInterpreter < Visitor
  COMPARATOR_FUNC = {
    "eq"  => ->(a : JSON::Any, b : JSON::Any) { TreeInterpreter.equals(a, b) },
    "ne"  => ->(a : JSON::Any, b : JSON::Any) { !TreeInterpreter.equals(a, b) },
    "lt"  => ->(a : JSON::Any, b : JSON::Any) { a.as_i < b.as_i },
    "gt"  => ->(a : JSON::Any, b : JSON::Any) { a.as_i > b.as_i },
    "lte" => ->(a : JSON::Any, b : JSON::Any) { a.as_i <= b.as_i },
    "gte" => ->(a : JSON::Any, b : JSON::Any) { a.as_i >= b.as_i },
  }

  def self.equals(a : JSON::Any, b : JSON::Any) : Bool
    a.raw == b.raw
  end

  def initialize(@options : Hash(String, JSON::Any)? = nil)
  end

  def default_visit(node : ASTNode, value : JSON::Any) : JSON::Any
    raise NotImplementedError.new("Unhandled node type: #{node.type}")
  end

  def visit_subexpression(node : ASTNode, value : JSON::Any) : JSON::Any
    result = value
    node.children.each do |child|
      result = visit(child, result)
    end
    result
  end

  def visit_field(node : ASTNode, value : JSON::Any) : JSON::Any
    field_name = node.value.to_s
    if value.as_h?.try(&.has_key?(field_name))
      value[field_name]
    else
      JSON::Any.new(nil)
    end
  end

  def visit_comparator(node : ASTNode, value : JSON::Any) : JSON::Any
    comparator = node.value.to_s
    left = visit(node.children[0], value)
    right = visit(node.children[1], value)

    result = if ["eq", "ne"].includes?(comparator)
               COMPARATOR_FUNC[comparator].call(left, right)
             else
               if left.raw.is_a?(Number) && right.raw.is_a?(Number)
                 COMPARATOR_FUNC[comparator].call(left, right)
               else
                 false
               end
             end

    JSON::Any.new(result)
  end

  def visit_current(node : ASTNode, value : JSON::Any) : JSON::Any
    value
  end

  def visit_literal(node : ASTNode, value : JSON::Any) : JSON::Any
    case node_value = node.value
    when Int32
      JSON::Any.new(node_value.to_i64)
    when String
      JSON::Any.new(node_value)
    when Char
      JSON::Any.new(node_value.to_s)
    when Float64
      JSON::Any.new(node_value)
    when Bool
      JSON::Any.new(node_value)
    else
      JSON::Any.new(nil)
    end
  end

  def visit_expref(node : ASTNode, value : JSON::Any) : JSON::Any
    raise NotImplementedError.new("visit_expref not implemented")
  end

  def visit_function_expression(node : ASTNode, value : JSON::Any) : JSON::Any
    raise NotImplementedError.new("visit_function_expression not implemented")
  end

  def visit_filter_projection(node : ASTNode, value : JSON::Any) : JSON::Any
    # Get base value
    base = visit(node.children[0], value)

    # Return nil if base is not an array
    array = base.as_a?
    return JSON::Any.new(nil) unless array

    puts "array: #{array}"

    # Get filter condition node
    comparator_node = node.children[2]

    # Collect results that match the filter condition
    collected = array.compact_map do |element|
      # Only include elements where condition is true
      if is_true(visit(comparator_node, element))
        current = visit(node.children[1], element)
        # Filter out nil values
        current unless current.raw.nil?
      end
    end

    JSON::Any.new(collected)
  end

  def visit_flatten(node : ASTNode, value : JSON::Any) : JSON::Any
    base = visit(node.children[0], value)
    array = base.as_a?
    return JSON::Any.new([] of JSON::Any) unless array

    merged_list = [] of JSON::Any
    array.each do |element|
      if elem_array = element.as_a?
        merged_list.concat(elem_array)
      else
        merged_list << element
      end
    end

    JSON::Any.new(merged_list)
  end

  def visit_identity(node : ASTNode, value : JSON::Any) : JSON::Any
    value
  end

  def visit_index(node : ASTNode, value : JSON::Any) : JSON::Any
    # Check if value is an array
    array = value.as_a?
    return JSON::Any.new(nil) unless array

    # Get index from node value
    index = node.value.as(Int32)

    # Try to access array at index
    begin
      array[index]
    rescue IndexError
      JSON::Any.new(nil)
    end
  end

  def visit_index_expression(node : ASTNode, value : JSON::Any) : JSON::Any
    result = value
    node.children.each do |child|
      result = visit(child, result)
    end
    result
  end

  def visit_slice(node : ASTNode, value : JSON::Any) : JSON::Any
    # Check if value is an array
    array = value.as_a?
    return JSON::Any.new(nil) unless array

    # Get slice parameters from children nodes
    start = visit(node.children[0], value).as_i?
    stop = visit(node.children[1], value).as_i?
    step = visit(node.children[2], value).as_i? || 1

    # Create sliced array
    begin
      start_idx = start || 0
      end_idx = stop || array.size

      # Get the slice and then filter by step
      result = [] of JSON::Any
      array[start_idx...end_idx].each_with_index do |element, index|
        result << element if index % step == 0
      end

      JSON::Any.new(result)
    rescue IndexError
      JSON::Any.new([] of JSON::Any)
    end
  end

  def visit_key_val_pair(node : ASTNode, value : JSON::Any) : JSON::Any
    raise NotImplementedError.new("visit_key_val_pair not implemented")
  end

  def visit_multi_select_dict(node : ASTNode, value : JSON::Any) : JSON::Any
    raise NotImplementedError.new("visit_multi_select_dict not implemented")
  end

  def visit_multi_select_list(node : ASTNode, value : JSON::Any) : JSON::Any
    # Return nil if input value is nil
    return JSON::Any.new(nil) if value.raw.nil?

    # Collect results from all children
    collected = node.children.map do |child|
      visit(child, value)
    end

    # Return array of collected results
    JSON::Any.new(collected)
  end

  def visit_or_expression(node : ASTNode, value : JSON::Any) : JSON::Any
    left = visit(node.children[0], value)
    return left unless is_false(left)

    right = visit(node.children[1], value)
    right
  end

  def visit_and_expression(node : ASTNode, value : JSON::Any) : JSON::Any
    left = visit(node.children[0], value)
    return JSON::Any.new(nil) if is_false(left)

    right = visit(node.children[1], value)
    right
  end

  def visit_not_expression(node : ASTNode, value : JSON::Any) : JSON::Any
    original_result = visit(node.children[0], value)
    JSON::Any.new(is_false(original_result))
  end

  def visit_pipe(node : ASTNode, value : JSON::Any) : JSON::Any
    # First evaluate the left expression
    left_result = visit(node.children[0], value)
    # Then use that result as input for the right expression
    visit(node.children[1], left_result)
  end

  def visit_projection(node : ASTNode, value : JSON::Any) : JSON::Any
    base = visit(node.children[0], value)

    # Check if base is an array
    array = base.as_a?
    return JSON::Any.new(nil) unless array

    # Collect results
    collected = array.compact_map do |element|
      current = visit(node.children[1], element)
      # Only include non-null values
      current unless current.raw.nil?
    end

    JSON::Any.new(collected)
  end

  def visit_value_projection(node : ASTNode, value : JSON::Any) : JSON::Any
    # Get base value
    base = visit(node.children[0], value)

    # Try to get hash values, return nil if not a hash
    hash = base.as_h?
    return JSON::Any.new(nil) unless hash

    # Collect results from hash values
    collected = hash.values.compact_map do |element|
      current = visit(node.children[1], element)
      # Only include non-null values
      current unless current.raw.nil?
    end

    JSON::Any.new(collected)
  end

  # Add other visit methods following the same pattern...

  private def is_true(value : JSON::Any) : Bool
    !is_false(value)
  end

  private def is_false(value : JSON::Any) : Bool
    case raw = value.raw
    when Nil
      true
    when String
      raw.empty?
    when Array
      raw.empty?
    when Hash
      raw.empty?
    when Bool
      !raw
    else
      false
    end
  end
end
