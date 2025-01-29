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
end
