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
end
