require "./spec_helper"

describe "JMESPath built-in functions" do
  # -- Number functions --

  describe "abs" do
    it "returns absolute value of positive number" do
      JMESPath.search("abs(foo)", %({"foo": 5})).as_i.should eq(5)
    end

    it "returns absolute value of negative number" do
      JMESPath.search("abs(foo)", %({"foo": -5})).as_i.should eq(5)
    end

    it "raises on non-number" do
      expect_raises(JMESPathTypeError) do
        JMESPath.search("abs(foo)", %({"foo": "string"}))
      end
    end
  end

  describe "avg" do
    it "computes average of number array" do
      JMESPath.search("avg(foo)", %({"foo": [10, 20, 30]})).as_f.should eq(20.0)
    end

    it "returns null for empty array" do
      JMESPath.search("avg(foo)", %({"foo": []})).raw.should be_nil
    end
  end

  describe "ceil" do
    it "rounds up a float" do
      JMESPath.search("ceil(`1.2`)", %({})).as_i.should eq(2)
    end

    it "returns integer unchanged" do
      JMESPath.search("ceil(`5`)", %({})).as_i.should eq(5)
    end
  end

  describe "floor" do
    it "rounds down a float" do
      JMESPath.search("floor(`1.9`)", %({})).as_i.should eq(1)
    end

    it "returns integer unchanged" do
      JMESPath.search("floor(`5`)", %({})).as_i.should eq(5)
    end
  end

  describe "sum" do
    it "sums integer array" do
      JMESPath.search("sum(foo)", %({"foo": [1, 2, 3]})).as_i.should eq(6)
    end

    it "returns 0 for empty array" do
      JMESPath.search("sum(foo)", %({"foo": []})).as_i.should eq(0)
    end
  end

  # -- String / array functions --

  describe "length" do
    it "returns length of string" do
      JMESPath.search("length(foo)", %({"foo": "hello"})).as_i.should eq(5)
    end

    it "returns length of array" do
      JMESPath.search("length(foo)", %({"foo": [1, 2, 3]})).as_i.should eq(3)
    end

    it "returns length of object" do
      JMESPath.search("length(foo)", %({"foo": {"a": 1, "b": 2}})).as_i.should eq(2)
    end
  end

  describe "reverse" do
    it "reverses a string" do
      JMESPath.search("reverse(foo)", %({"foo": "hello"})).as_s.should eq("olleh")
    end

    it "reverses an array" do
      result = JMESPath.search("reverse(foo)", %({"foo": [1, 2, 3]})).as_a
      result.map(&.as_i).should eq([3, 2, 1])
    end
  end

  describe "sort" do
    it "sorts string array" do
      result = JMESPath.search("sort(foo)", %({"foo": ["c", "a", "b"]})).as_a
      result.map(&.as_s).should eq(["a", "b", "c"])
    end

    it "sorts number array" do
      result = JMESPath.search("sort(foo)", %({"foo": [3, 1, 2]})).as_a
      result.map(&.as_i).should eq([1, 2, 3])
    end

    it "returns empty array unchanged" do
      JMESPath.search("sort(foo)", %({"foo": []})).as_a.size.should eq(0)
    end
  end

  describe "join" do
    it "joins array with separator" do
      JMESPath.search("join(', ', foo)", %({"foo": ["a", "b", "c"]})).as_s.should eq("a, b, c")
    end

    it "joins with empty separator" do
      JMESPath.search("join('', foo)", %({"foo": ["a", "b"]})).as_s.should eq("ab")
    end
  end

  describe "contains" do
    it "checks string contains substring" do
      JMESPath.search("contains(foo, 'll')", %({"foo": "hello"})).as_bool.should be_true
    end

    it "returns false for missing substring" do
      JMESPath.search("contains(foo, 'xyz')", %({"foo": "hello"})).as_bool.should be_false
    end

    it "checks array contains element" do
      JMESPath.search("contains(foo, `2`)", %({"foo": [1, 2, 3]})).as_bool.should be_true
    end

    it "returns false for missing element" do
      JMESPath.search("contains(foo, `5`)", %({"foo": [1, 2, 3]})).as_bool.should be_false
    end
  end

  describe "starts_with" do
    it "returns true for matching prefix" do
      JMESPath.search("starts_with(foo, 'hel')", %({"foo": "hello"})).as_bool.should be_true
    end

    it "returns false for non-matching prefix" do
      JMESPath.search("starts_with(foo, 'xyz')", %({"foo": "hello"})).as_bool.should be_false
    end
  end

  describe "ends_with" do
    it "returns true for matching suffix" do
      JMESPath.search("ends_with(foo, 'llo')", %({"foo": "hello"})).as_bool.should be_true
    end

    it "returns false for non-matching suffix" do
      JMESPath.search("ends_with(foo, 'xyz')", %({"foo": "hello"})).as_bool.should be_false
    end
  end

  # -- Object functions --

  describe "keys" do
    it "returns object keys" do
      result = JMESPath.search("keys(foo)", %({"foo": {"a": 1, "b": 2}})).as_a
      result.map(&.as_s).sort.should eq(["a", "b"])
    end
  end

  describe "values" do
    it "returns object values" do
      result = JMESPath.search("values(foo)", %({"foo": {"a": 1, "b": 2}})).as_a
      result.map(&.as_i).sort.should eq([1, 2])
    end
  end

  describe "merge" do
    it "merges two objects" do
      result = JMESPath.search("merge(foo, bar)", %({"foo": {"a": 1}, "bar": {"b": 2}})).as_h
      result["a"].as_i.should eq(1)
      result["b"].as_i.should eq(2)
    end

    it "later values override earlier" do
      result = JMESPath.search("merge(foo, bar)", %({"foo": {"a": 1}, "bar": {"a": 2}})).as_h
      result["a"].as_i.should eq(2)
    end
  end

  # -- Conversion functions --

  describe "type" do
    it "returns type names" do
      JMESPath.search("type(foo)", %({"foo": "hello"})).as_s.should eq("string")
      JMESPath.search("type(foo)", %({"foo": 42})).as_s.should eq("number")
      JMESPath.search("type(foo)", %({"foo": true})).as_s.should eq("boolean")
      JMESPath.search("type(foo)", %({"foo": null})).as_s.should eq("null")
      JMESPath.search("type(foo)", %({"foo": [1]})).as_s.should eq("array")
      JMESPath.search("type(foo)", %({"foo": {"a": 1}})).as_s.should eq("object")
    end
  end

  describe "to_array" do
    it "wraps non-array in array" do
      result = JMESPath.search("to_array(foo)", %({"foo": "hello"})).as_a
      result.size.should eq(1)
      result[0].as_s.should eq("hello")
    end

    it "returns array unchanged" do
      result = JMESPath.search("to_array(foo)", %({"foo": [1, 2]})).as_a
      result.map(&.as_i).should eq([1, 2])
    end
  end

  describe "to_string" do
    it "returns string unchanged" do
      JMESPath.search("to_string(foo)", %({"foo": "hello"})).as_s.should eq("hello")
    end

    it "converts number to string" do
      JMESPath.search("to_string(foo)", %({"foo": 42})).as_s.should eq("42")
    end
  end

  describe "to_number" do
    it "returns number unchanged" do
      JMESPath.search("to_number(foo)", %({"foo": 42})).as_i.should eq(42)
    end

    it "converts numeric string to number" do
      JMESPath.search("to_number(foo)", %({"foo": "42"})).as_i.should eq(42)
    end

    it "returns null for non-numeric string" do
      JMESPath.search("to_number(foo)", %({"foo": "abc"})).raw.should be_nil
    end

    it "returns null for boolean" do
      JMESPath.search("to_number(foo)", %({"foo": true})).raw.should be_nil
    end
  end

  # -- Min / max --

  describe "max" do
    it "finds max in number array" do
      JMESPath.search("max(foo)", %({"foo": [3, 1, 5, 2]})).as_i.should eq(5)
    end

    it "finds max in string array" do
      JMESPath.search("max(foo)", %({"foo": ["b", "a", "c"]})).as_s.should eq("c")
    end

    it "returns null for empty array" do
      JMESPath.search("max(foo)", %({"foo": []})).raw.should be_nil
    end
  end

  describe "min" do
    it "finds min in number array" do
      JMESPath.search("min(foo)", %({"foo": [3, 1, 5, 2]})).as_i.should eq(1)
    end

    it "finds min in string array" do
      JMESPath.search("min(foo)", %({"foo": ["b", "a", "c"]})).as_s.should eq("a")
    end
  end

  describe "not_null" do
    it "returns first non-null" do
      JMESPath.search("not_null(a, b, c)", %({"a": null, "b": "hello", "c": "world"})).as_s.should eq("hello")
    end

    it "returns null when all null" do
      JMESPath.search("not_null(a, b)", %({"a": null, "b": null})).raw.should be_nil
    end
  end

  # -- Expref functions --

  describe "sort_by" do
    it "sorts objects by expression" do
      data = %({"people": [{"name": "bob", "age": 30}, {"name": "alice", "age": 25}, {"name": "charlie", "age": 35}]})
      result = JMESPath.search("sort_by(people, &age)", data).as_a
      result.map { |r| r["name"].as_s }.should eq(["alice", "bob", "charlie"])
    end

    it "sorts by string expression" do
      data = %({"people": [{"name": "bob"}, {"name": "alice"}, {"name": "charlie"}]})
      result = JMESPath.search("sort_by(people, &name)", data).as_a
      result.map { |r| r["name"].as_s }.should eq(["alice", "bob", "charlie"])
    end

    it "returns empty array unchanged" do
      JMESPath.search("sort_by(foo, &bar)", %({"foo": []})).as_a.size.should eq(0)
    end
  end

  describe "max_by" do
    it "finds max by expression" do
      data = %({"people": [{"name": "bob", "age": 30}, {"name": "alice", "age": 25}, {"name": "charlie", "age": 35}]})
      JMESPath.search("max_by(people, &age)", data).as_h["name"].as_s.should eq("charlie")
    end

    it "returns null for empty array" do
      JMESPath.search("max_by(foo, &bar)", %({"foo": []})).raw.should be_nil
    end
  end

  describe "min_by" do
    it "finds min by expression" do
      data = %({"people": [{"name": "bob", "age": 30}, {"name": "alice", "age": 25}, {"name": "charlie", "age": 35}]})
      JMESPath.search("min_by(people, &age)", data).as_h["name"].as_s.should eq("alice")
    end
  end

  describe "map" do
    it "maps expression over array" do
      data = %({"people": [{"name": "bob", "age": 30}, {"name": "alice", "age": 25}]})
      result = JMESPath.search("map(&age, people)", data).as_a
      result.map(&.as_i).should eq([30, 25])
    end
  end

  # -- Expref (expression reference) edge cases --

  describe "expref" do
    it "sort_by with nested key access" do
      data = %({"items": [
        {"info": {"priority": 3}},
        {"info": {"priority": 1}},
        {"info": {"priority": 2}}
      ]})
      result = JMESPath.search("sort_by(items, &info.priority)", data).as_a
      result.map { |r| r["info"]["priority"].as_i }.should eq([1, 2, 3])
    end

    it "map with nested key access" do
      data = %({"items": [
        {"info": {"name": "a"}},
        {"info": {"name": "b"}}
      ]})
      result = JMESPath.search("map(&info.name, items)", data).as_a
      result.map(&.as_s).should eq(["a", "b"])
    end

    it "max_by with nested key" do
      data = %({"items": [
        {"stats": {"score": 10}},
        {"stats": {"score": 50}},
        {"stats": {"score": 30}}
      ]})
      JMESPath.search("max_by(items, &stats.score)", data).as_h["stats"]["score"].as_i.should eq(50)
    end

    it "min_by with nested key" do
      data = %({"items": [
        {"stats": {"score": 10}},
        {"stats": {"score": 50}},
        {"stats": {"score": 30}}
      ]})
      JMESPath.search("min_by(items, &stats.score)", data).as_h["stats"]["score"].as_i.should eq(10)
    end

    it "sort_by then project a field" do
      data = %({"people": [
        {"name": "charlie", "age": 35},
        {"name": "alice", "age": 25},
        {"name": "bob", "age": 30}
      ]})
      result = JMESPath.search("sort_by(people, &age)[*].name", data).as_a
      result.map(&.as_s).should eq(["alice", "bob", "charlie"])
    end

    it "sort_by result piped to reverse" do
      data = %({"people": [
        {"name": "charlie", "age": 35},
        {"name": "alice", "age": 25},
        {"name": "bob", "age": 30}
      ]})
      result = JMESPath.search("sort_by(people, &age) | reverse(@)", data).as_a
      result.map { |r| r["name"].as_s }.should eq(["charlie", "bob", "alice"])
    end

    it "max_by with string comparison" do
      data = %({"items": [{"id": "alpha"}, {"id": "gamma"}, {"id": "beta"}]})
      JMESPath.search("max_by(items, &id)", data).as_h["id"].as_s.should eq("gamma")
    end

    it "min_by with string comparison" do
      data = %({"items": [{"id": "alpha"}, {"id": "gamma"}, {"id": "beta"}]})
      JMESPath.search("min_by(items, &id)", data).as_h["id"].as_s.should eq("alpha")
    end

    it "map with length function in expression" do
      data = %({"words": ["hello", "hi", "hey"]})
      result = JMESPath.search("map(&length(@), words)", data).as_a
      result.map(&.as_i).should eq([5, 2, 3])
    end

    it "sort_by combined with max_by" do
      data = %({"groups": [
        {"name": "a", "values": [1, 2, 3]},
        {"name": "b", "values": [10, 20, 30, 40]},
        {"name": "c", "values": [5]}
      ]})
      result = JMESPath.search("max_by(groups, &length(values))", data).as_h
      result["name"].as_s.should eq("b")
    end

    it "map expref with index access" do
      data = %({"items": [[1, 2, 3], [4, 5, 6], [7, 8, 9]]})
      result = JMESPath.search("map(&[0], items)", data).as_a
      result.map(&.as_i).should eq([1, 4, 7])
    end

    it "sort_by with filter on result" do
      data = %({"people": [
        {"name": "alice", "age": 25},
        {"name": "bob", "age": 30},
        {"name": "charlie", "age": 20}
      ]})
      result = JMESPath.search("sort_by(people, &age)[?age > `22`].name", data).as_a
      result.map(&.as_s).should eq(["alice", "bob"])
    end

    it "map with multi-select hash" do
      data = %({"people": [
        {"first": "Alice", "last": "Smith", "age": 25},
        {"first": "Bob", "last": "Jones", "age": 30}
      ]})
      result = JMESPath.search("map(&{name: first, surname: last}, people)", data).as_a
      result[0].as_h["name"].as_s.should eq("Alice")
      result[0].as_h["surname"].as_s.should eq("Smith")
      result[1].as_h["name"].as_s.should eq("Bob")
    end
  end

  # -- Error handling --

  describe "error handling" do
    it "raises on unknown function" do
      expect_raises(UnknownFunctionError) do
        JMESPath.search("unknown_func(foo)", %({"foo": 1}))
      end
    end

    it "raises on wrong arity" do
      expect_raises(ArityError) do
        JMESPath.search("abs(foo, bar)", %({"foo": 1, "bar": 2}))
      end
    end

    it "raises on wrong type" do
      expect_raises(JMESPathTypeError) do
        JMESPath.search("length(`42`)", %({}))
      end
    end
  end

  # -- Combined expressions --

  describe "combined with other features" do
    it "uses functions with projections" do
      data = %({"people": [{"name": "bob"}, {"name": "alice"}, {"name": "charlie"}]})
      result = JMESPath.search("length(people[*].name)", data).as_i
      result.should eq(3)
    end

    it "uses functions with filters" do
      data = %({"people": [{"name": "bob", "age": 20}, {"name": "alice", "age": 25}, {"name": "charlie", "age": 30}]})
      result = JMESPath.search("length(people[?age > `20`])", data).as_i
      result.should eq(2)
    end

    it "uses functions in pipe expressions" do
      data = %({"foo": [3, 1, 2]})
      result = JMESPath.search("foo | sort(@) | [0]", data).as_i
      result.should eq(1)
    end

    it "chains function results" do
      data = %({"foo": "hello world"})
      result = JMESPath.search("length(foo)", data).as_i
      result.should eq(11)
    end

    it "sort_by with filter" do
      data = %({"people": [
        {"name": "bob", "age": 30},
        {"name": "alice", "age": 25},
        {"name": "charlie", "age": 35},
        {"name": "dave", "age": 20}
      ]})
      result = JMESPath.search("sort_by(people[?age > `22`], &age)[*].name", data).as_a
      result.map(&.as_s).should eq(["alice", "bob", "charlie"])
    end
  end
end
