require "./spec_helper"

describe JMESPath do
  describe ".search" do
    it "handles basic object access" do
      data = %({"foo": {"bar": "baz"}})
      JMESPath.search("foo.bar", data).as_s.should eq("baz")
    end

    it "handles array operations" do
      data = %({"people": [{"name": "bob"}, {"name": "alice"}]})
      result = JMESPath.search("people[1].name", data)
      result.as_s.should eq("alice")
    end

    it "handles list projections" do
      data = %({"people": [{"age": 20}, {"age": 25}, {"age": 30}]})
      result = JMESPath.search("people[*].age", data)
      result.as_a.map(&.as_i).should eq([20, 25, 30])
    end

    it "handles filters" do
      data = %({"people": [{"name": "bob", "age": 20}, {"name": "alice", "age": 25}]})
      result = JMESPath.search("people[?age > `20`].name", data)
      result.as_a.map(&.as_s).should eq(["alice"])
    end

    it "handles nested expressions" do
      data = %({
        "store": {
          "books": [
            {"title": "Book A", "price": 10},
            {"title": "Book B", "price": 20}
          ]
        }
      })
      result = JMESPath.search("store.books[?price > `15`].title", data)
      result.as_a.map(&.as_s).should eq(["Book B"])
    end

    it "handles multi-select hash" do
      data = %({"foo": {"bar": "baz", "qux": "quux"}})
      result = JMESPath.search("foo.{b: bar, q: qux}", data)
      result["b"].as_s.should eq("baz")
      result["q"].as_s.should eq("quux")
    end
  end
end
