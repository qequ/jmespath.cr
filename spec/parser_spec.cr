require "./spec_helper"
require "../src/parser" # Adjust path as necessary
require "json"

describe Parser do
  it "parses a field" do
    parser = Parser.new
    result = parser.parse("foo")
    result.parsed.type.should eq("field")
    result.parsed.value.should eq("foo")
  end

  it "parses a subexpression with dot operator" do
    parser = Parser.new
    result = parser.parse("foo.baz")
    result.parsed.type.should eq("subexpression")
    result.parsed.children[0].type.should eq("field")
    result.parsed.children[0].value.should eq("foo")
    result.parsed.children[1].type.should eq("field")
    result.parsed.children[1].value.should eq("baz")
  end

  it "parses and evaluates nested dot expressions" do
    parser = Parser.new
    result = parser.parse("foo.bar")

    # Test the parsed structure
    result.parsed.type.should eq("subexpression")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("field")
    result.parsed.children[0].value.should eq("foo")
    result.parsed.children[1].type.should eq("field")
    result.parsed.children[1].value.should eq("bar")

    # Test the evaluation
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new({"bar" => JSON::Any.new("baz")}),
    })

    result.search(json_data).as_s.should eq("baz")
  end

  it "parses and evaluates triple dot expressions" do
    parser = Parser.new
    result = parser.parse("foo.bar.baz")

    # Test the evaluation
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new({
        "bar" => JSON::Any.new({
          "baz" => JSON::Any.new("qux"),
        }),
      }),
    })

    result.search(json_data).as_s.should eq("qux")
  end

  it "parses and evaluates array index expressions" do
    parser = Parser.new
    result = parser.parse("data[1]")

    # Test the evaluation
    array_data = [10, 20, 30].map { |n| JSON::Any.new(n.to_i64) }
    json_data = JSON::Any.new({
      "data" => JSON::Any.new(array_data),
    })

    result.search(json_data).as_i.should eq(20)
  end

  it "parses and evaluates or expressions" do
    parser = Parser.new
    result = parser.parse("foo || bar")

    # Test when first operand exists
    json_data1 = JSON::Any.new({
      "foo" => JSON::Any.new("foo"),
      "bar" => JSON::Any.new("bar"),
    })
    result.search(json_data1).as_s.should eq("foo")

    # Test when first operand is missing, should return nil
    json_data2 = JSON::Any.new({
      "bad" => JSON::Any.new("bad"),
    })
    result.search(json_data2).raw.should be_nil
  end

  it "parses and evaluates array projections" do
    parser = Parser.new
    result = parser.parse("foo[*]")

    # Test the parsed structure
    result.parsed.type.should eq("projection")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("field")
    result.parsed.children[0].value.should eq("foo")
    result.parsed.children[1].type.should eq("identity")

    # Test the evaluation
    array_data = [10, 20, 30].map { |n| JSON::Any.new(n.to_i64) }
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(array_data),
    })

    result = result.search(json_data).as_a
    result.size.should eq(3)
    result[0].as_i.should eq(10)
    result[1].as_i.should eq(20)
    result[2].as_i.should eq(30)
  end

  it "parses and evaluates nested array projections" do
    parser = Parser.new
    result = parser.parse("foo[*].bar")

    # Test the parsed structure
    result.parsed.type.should eq("projection")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("field")
    result.parsed.children[0].value.should eq("foo")
    result.parsed.children[1].type.should eq("field")
    result.parsed.children[1].value.should eq("bar")

    # Test the evaluation
    array_data = [
      {"bar" => JSON::Any.new("baz")},
      {"bar" => JSON::Any.new("qux")},
    ].map { |h| JSON::Any.new(h) }

    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(array_data),
    })

    result = result.search(json_data).as_a
    result.size.should eq(2)
    result[0].as_s.should eq("baz")
    result[1].as_s.should eq("qux")
  end

  it "parses and evaluates single-level flatten" do
    parser = Parser.new
    result = parser.parse("foo[]")

    # Test the parsed structure
    result.parsed.type.should eq("projection")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("flatten")
    result.parsed.children[0].children[0].type.should eq("field")
    result.parsed.children[0].children[0].value.should eq("foo")
    result.parsed.children[1].type.should eq("identity")

    # Create nested JSON::Any structure
    inner_arrays = [
      [
        ["one", "two"].map { |s| JSON::Any.new(s) },
        ["three", "four"].map { |s| JSON::Any.new(s) },
      ].map { |arr| JSON::Any.new(arr) },
      [
        ["five", "six"].map { |s| JSON::Any.new(s) },
        ["seven", "eight"].map { |s| JSON::Any.new(s) },
      ].map { |arr| JSON::Any.new(arr) },
      [
        ["nine"].map { |s| JSON::Any.new(s) },
        ["ten"].map { |s| JSON::Any.new(s) },
      ].map { |arr| JSON::Any.new(arr) },
    ].map { |arr| JSON::Any.new(arr) }

    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(inner_arrays),
    })

    # Test the flattened result
    flattened = result.search(json_data).as_a
    flattened.size.should eq(6)

    flattened[0].as_a.map(&.as_s).should eq(["one", "two"])
    flattened[1].as_a.map(&.as_s).should eq(["three", "four"])
    flattened[2].as_a.map(&.as_s).should eq(["five", "six"])
    flattened[3].as_a.map(&.as_s).should eq(["seven", "eight"])
    flattened[4].as_a.map(&.as_s).should eq(["nine"])
    flattened[5].as_a.map(&.as_s).should eq(["ten"])
  end

  it "parses and evaluates flatten followed by index" do
    parser = Parser.new
    result = parser.parse("foo[][0]")

    # Test the parsed structure
    result.parsed.type.should eq("projection")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("flatten")
    result.parsed.children[1].type.should eq("index_expression")

    # Create nested JSON::Any structure
    inner_arrays = [
      [
        ["one", "two"].map { |s| JSON::Any.new(s) },
        ["three", "four"].map { |s| JSON::Any.new(s) },
      ].map { |arr| JSON::Any.new(arr) },
      [
        ["five", "six"].map { |s| JSON::Any.new(s) },
        ["seven", "eight"].map { |s| JSON::Any.new(s) },
      ].map { |arr| JSON::Any.new(arr) },
      [
        ["nine"].map { |s| JSON::Any.new(s) },
        ["ten"].map { |s| JSON::Any.new(s) },
      ].map { |arr| JSON::Any.new(arr) },
    ].map { |arr| JSON::Any.new(arr) }

    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(inner_arrays),
    })

    # Test the result
    final_array = result.search(json_data).as_a
    final_array.size.should eq(6)
    final_array.map(&.as_s).should eq(
      ["one", "three", "five", "seven", "nine", "ten"]
    )
  end

  it "parses and evaluates comparator expressions" do
    parser = Parser.new

    # Test greater than
    result = parser.parse("foo > bar")
    result.parsed.type.should eq("comparator")
    result.parsed.value.should eq("gt")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("field")
    result.parsed.children[0].value.should eq("foo")
    result.parsed.children[1].type.should eq("field")
    result.parsed.children[1].value.should eq("bar")

    # Test numeric comparison
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(3),
      "bar" => JSON::Any.new(2),
    })
    result.search(json_data).as_bool.should eq(true)

    # Test less than or equal
    result = parser.parse("foo <= bar")
    result.parsed.type.should eq("comparator")
    result.parsed.value.should eq("lte")

    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(2),
      "bar" => JSON::Any.new(2),
    })
    result.search(json_data).as_bool.should eq(true)

    # Test equality
    result = parser.parse("foo == bar")
    result.parsed.type.should eq("comparator")
    result.parsed.value.should eq("eq")

    json_data = JSON::Any.new({
      "foo" => JSON::Any.new("value"),
      "bar" => JSON::Any.new("value"),
    })
    result.search(json_data).as_bool.should eq(true)

    # Test not equals
    result = parser.parse("foo != bar")
    result.parsed.type.should eq("comparator")
    result.parsed.value.should eq("ne")

    json_data = JSON::Any.new({
      "foo" => JSON::Any.new("value1"),
      "bar" => JSON::Any.new("value2"),
    })
    result.search(json_data).as_bool.should eq(true)
  end

  it "parses and evaluates standalone star expression" do
    parser = Parser.new
    result = parser.parse("*")

    # Test the parsed structure
    result.parsed.type.should eq("value_projection")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("identity")
    result.parsed.children[1].type.should eq("identity")

    # Test evaluation with object
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(10),
      "bar" => JSON::Any.new(20),
      "baz" => JSON::Any.new(30),
    })

    search_result = result.search(json_data).as_a
    search_result.size.should eq(3)
    search_result.map(&.as_i).sort.should eq([10, 20, 30])
  end

  it "parses and evaluates not expressions" do
    parser = Parser.new
    result = parser.parse("!foo")

    # Test the parsed structure
    result.parsed.type.should eq("not_expression")
    result.parsed.children.size.should eq(1)
    result.parsed.children[0].type.should eq("field")
    result.parsed.children[0].value.should eq("foo")

    # Test with true value
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(true),
    })
    result.search(json_data).as_bool.should eq(false)

    # Test with false value
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(false),
    })
    result.search(json_data).as_bool.should eq(true)

    # Test with null/nil value
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new(nil),
    })
    result.search(json_data).as_bool.should eq(true)

    # Test with non-existent key
    json_data = JSON::Any.new({
      "bar" => JSON::Any.new(true),
    })
    result.search(json_data).as_bool.should eq(true)
  end

  it "parses and evaluates pipe expressions" do
    parser = Parser.new

    # Test basic pipe expression
    result = parser.parse("foo | [0]")

    # Test evaluation with array
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new([10, 20, 30].map { |n| JSON::Any.new(n.to_i64) }),
    })
    result.search(json_data).as_i.should eq(10)

    # Test chained pipe expressions
    result = parser.parse("foo | [0] | bar")

    # Test evaluation with nested data
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new([
        {"bar" => JSON::Any.new("first")},
        {"bar" => JSON::Any.new("second")},
      ].map { |h| JSON::Any.new(h) }),
    })
    result.search(json_data).as_s.should eq("first")
  end

  it "parses and evaluates expressions with parentheses" do
    parser = Parser.new
    result = parser.parse("(foo).bar")

    # Test the parsed structure
    result.parsed.type.should eq("subexpression")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("field")
    result.parsed.children[0].value.should eq("foo")
    result.parsed.children[1].type.should eq("field")
    result.parsed.children[1].value.should eq("bar")

    # Test evaluation
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new({
        "bar" => JSON::Any.new("baz"),
      }),
    })
    result.search(json_data).as_s.should eq("baz")

    # Test nested parentheses
    result = parser.parse("((foo))")
    result.parsed.type.should eq("field")
    result.parsed.value.should eq("foo")

    json_data = JSON::Any.new({
      "foo" => JSON::Any.new("value"),
    })
    result.search(json_data).as_s.should eq("value")
  end

  it "parses and evaluates multi-select list expressions" do
    parser = Parser.new
    parsed_result = parser.parse("foo.[bar, baz]")

    # Test the parsed structure
    # Test evaluation
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new({
        "bar" => JSON::Any.new(1),
        "baz" => JSON::Any.new(2),
        "qux" => JSON::Any.new(3),
      }),
    })

    search_result = parsed_result.search(json_data).as_a
    search_result.size.should eq(2)
    search_result[0].as_i.should eq(1)
    search_result[1].as_i.should eq(2)

    # Test with nil value
    json_data = JSON::Any.new(nil)
    parsed_result.search(json_data).raw.should be_nil
  end

  # test boolean experssion (a || b) && c
  it "parses and evaluates boolean expressions" do
    parser = Parser.new
    result = parser.parse("(a || b) && c")

    # Test the parsed structure
    result.parsed.type.should eq("and_expression")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("or_expression")
    result.parsed.children[1].type.should eq("field")

    # Test the evaluation
    json_data = JSON::Any.new({
      "a" => JSON::Any.new(false),
      "b" => JSON::Any.new(true),
      "c" => JSON::Any.new(false),
    })
    result.search(json_data).as_bool.should eq(false)
  end

  it "parses and evaluates array projections with missing fields" do
    parser = Parser.new
    result = parser.parse("[*].foo")

    # Test evaluation with all objects having 'foo'
    json_data = JSON::Any.new([
      {"foo" => JSON::Any.new(1)},
      {"foo" => JSON::Any.new(2)},
      {"foo" => JSON::Any.new(3)},
    ].map { |h| JSON::Any.new(h) })

    search_result = result.search(json_data).as_a
    search_result.size.should eq(3)
    search_result.map(&.as_i).should eq([1, 2, 3])

    # Test evaluation with missing 'foo' field
    json_data = JSON::Any.new([
      {"foo" => JSON::Any.new(1)},
      {"foo" => JSON::Any.new(2)},
      {"bar" => JSON::Any.new(3)},
    ].map { |h| JSON::Any.new(h) })

    search_result = result.search(json_data).as_a
    search_result.size.should eq(2)
    search_result.map(&.as_i).should eq([1, 2])
  end

  it "parses and evaluates multi-select list on objects" do
    parser = Parser.new
    result = parser.parse("[foo, bar]")

    # Test evaluation with simple object
    json_data = JSON::Any.new({
      "foo" => JSON::Any.new("a"),
      "bar" => JSON::Any.new("b"),
      "baz" => JSON::Any.new("c"),
    })

    search_result = result.search(json_data).as_a
    search_result.size.should eq(2)
    search_result.map(&.as_s).should eq(["a", "b"])
  end

  # now parse a || (b && c)
  it "parses and evaluates boolean expressions with precedence" do
    parser = Parser.new
    result = parser.parse("a || (b && c)")

    # Test the parsed structure
    result.parsed.type.should eq("or_expression")
    result.parsed.children.size.should eq(2)
    result.parsed.children[0].type.should eq("field")
    result.parsed.children[1].type.should eq("and_expression")

    # Test the evaluation
    json_data = JSON::Any.new({
      "a" => JSON::Any.new(false),
      "b" => JSON::Any.new(true),
      "c" => JSON::Any.new(false),
    })
    result.search(json_data).as_bool.should eq(false)
  end
end
