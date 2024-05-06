struct Node
  property type : String
  property children : Array(Node)
  property value : String | Int32 | Nil

  def initialize(@type, @children = [] of Node, @value = nil)
  end
end

def comparator(name : String, first : Node, second : Node)
  Node.new("comparator", [first, second], name)
end

def current_node
  Node.new("current")
end

def expref(expression : Node)
  Node.new("expref", [expression])
end

def function_expression(name : String, args : Array(Node))
  Node.new("function_expression", args, name)
end

def field(name : String)
  Node.new("field", [] of Node, name)
end

def filter_projection(left : Node, right : Node, comparator : Node)
  Node.new("filter_projection", [left, right, comparator])
end

def flatten(node : Node)
  Node.new("flatten", [node])
end

def identity
  Node.new("identity")
end

def index(index : Int32)
  Node.new("index", [] of Node, index)
end

def index_expression(children : Array(Node))
  Node.new("index_expression", children)
end

def key_val_pair(key_name : String, node : Node)
  Node.new("key_val_pair", [node], key_name)
end

def literal(literal_value : String | Int32)
  Node.new("literal", [] of Node, literal_value)
end

def multi_select_dict(nodes : Array(Node))
  Node.new("multi_select_dict", nodes)
end

def multi_select_list(nodes : Array(Node))
  Node.new("multi_select_list", nodes)
end

def or_expression(left : Node, right : Node)
  Node.new("or_expression", [left, right])
end

def and_expression(left : Node, right : Node)
  Node.new("and_expression", [left, right])
end

def not_expression(expr : Node)
  Node.new("not_expression", [expr])
end

def pipe(left : Node, right : Node)
  Node.new("pipe", [left, right])
end

def projection(left : Node, right : Node)
  Node.new("projection", [left, right])
end

def subexpression(children : Array(Node))
  Node.new("subexpression", children)
end

def slice(start : Node, _end : Node, step : Node)
  Node.new("slice", [start, _end, step])
end

def value_projection(left : Node, right : Node)
  Node.new("value_projection", [left, right])
end
