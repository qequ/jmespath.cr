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
end
