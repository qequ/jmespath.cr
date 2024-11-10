struct ASTNode
  property type : String
  property children : Array(ASTNode)
  property value : Char | Int32 | String | Nil

  def initialize(@type, @children = [] of ASTNode, @value = nil)
  end
end

def comparator(name : String, first : ASTNode, second : ASTNode)
  ASTNode.new("comparator", [first, second], name)
end

def current_node
  ASTNode.new("current")
end

def expref(expression : ASTNode)
  ASTNode.new("expref", [expression])
end

def function_expression(name : String, args : Array(ASTNode))
  ASTNode.new("function_expression", args, name)
end

def field(name : Char | Int32 | String | Nil)
  ASTNode.new("field", [] of ASTNode, name)
end

def filter_projection(left : ASTNode, right : ASTNode, comparator : ASTNode)
  ASTNode.new("filter_projection", [left, right, comparator])
end

def flatten(node : ASTNode)
  ASTNode.new("flatten", [node])
end

def identity
  ASTNode.new("identity")
end

def index(index : Int32)
  ASTNode.new("index", [] of ASTNode, index)
end

def index_expression(children : Array(ASTNode))
  ASTNode.new("index_expression", children)
end

def key_val_pair(key_name : String, node : ASTNode)
  ASTNode.new("key_val_pair", [node], key_name)
end

def literal(literal_value : Char | Int32 | String | Nil)
  ASTNode.new("literal", [] of ASTNode, literal_value)
end

def multi_select_dict(nodes : Array(ASTNode))
  ASTNode.new("multi_select_dict", nodes)
end

def multi_select_list(nodes : Array(ASTNode))
  ASTNode.new("multi_select_list", nodes)
end

def or_expression(left : ASTNode, right : ASTNode)
  ASTNode.new("or_expression", [left, right])
end

def and_expression(left : ASTNode, right : ASTNode)
  ASTNode.new("and_expression", [left, right])
end

def not_expression(expr : ASTNode)
  ASTNode.new("not_expression", [expr])
end

def pipe(left : ASTNode, right : ASTNode)
  ASTNode.new("pipe", [left, right])
end

def projection(left : ASTNode, right : ASTNode)
  ASTNode.new("projection", [left, right])
end

def subexpression(children : Array(ASTNode))
  ASTNode.new("subexpression", children)
end

def slice(start : ASTNode, _end : ASTNode, step : ASTNode)
  ASTNode.new("slice", [start, _end, step])
end

def value_projection(left : ASTNode, right : ASTNode)
  ASTNode.new("value_projection", [left, right])
end
