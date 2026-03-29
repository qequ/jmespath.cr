# JMESPath.cr

A fully compliant Crystal implementation of [JMESPath](https://jmespath.org/), a query language for JSON. JMESPath allows you to declaratively extract elements from complex JSON documents.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     jmespath:
       github: qequ/jmespath.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "jmespath"

# Basic object access
data = %({"foo": {"bar": "baz"}})
JMESPath.search("foo.bar", data) # => "baz"

# Array operations
data = %({"people": [{"name": "bob"}, {"name": "alice"}]})
JMESPath.search("people[1].name", data) # => "alice"

# List projections
data = %({"people": [{"age": 20}, {"age": 25}, {"age": 30}]})
JMESPath.search("people[*].age", data) # => [20, 25, 30]

# Filters
data = %({"people": [
  {"name": "bob", "age": 20},
  {"name": "alice", "age": 25}
]})
JMESPath.search("people[?age > `20`].name", data) # => ["alice"]

# Multi-select hash
data = %({"foo": {"bar": "baz", "qux": "quux"}})
JMESPath.search("foo.{b: bar, q: qux}", data) # => {"b": "baz", "q": "quux"}
```

### Built-in Functions

```crystal
# String functions
JMESPath.search("length(foo)", %({"foo": "hello"}))           # => 5
JMESPath.search("starts_with(foo, 'hel')", %({"foo": "hello"})) # => true
JMESPath.search("join(', ', foo)", %({"foo": ["a", "b", "c"]})) # => "a, b, c"

# Array functions
JMESPath.search("sort(foo)", %({"foo": [3, 1, 2]}))     # => [1, 2, 3]
JMESPath.search("reverse(foo)", %({"foo": [1, 2, 3]}))  # => [3, 2, 1]
JMESPath.search("contains(foo, `2`)", %({"foo": [1, 2, 3]})) # => true

# Number functions
JMESPath.search("sum(foo)", %({"foo": [1, 2, 3]}))  # => 6
JMESPath.search("avg(foo)", %({"foo": [10, 20, 30]})) # => 20.0
JMESPath.search("abs(foo)", %({"foo": -5}))          # => 5

# Object functions
JMESPath.search("keys(foo)", %({"foo": {"a": 1, "b": 2}}))   # => ["a", "b"]
JMESPath.search("values(foo)", %({"foo": {"a": 1, "b": 2}})) # => [1, 2]

# Type conversion
JMESPath.search("to_string(foo)", %({"foo": 42}))    # => "42"
JMESPath.search("to_number(foo)", %({"foo": "42"}))   # => 42
JMESPath.search("type(foo)", %({"foo": "hello"}))     # => "string"
```

### Expression References (expref)

The `&` operator creates a reference to an expression that is evaluated later by functions like `sort_by`, `max_by`, `min_by`, and `map`:

```crystal
# Sort by a field
data = %({"people": [{"name": "bob", "age": 30}, {"name": "alice", "age": 25}]})
JMESPath.search("sort_by(people, &age)[*].name", data) # => ["alice", "bob"]

# Find max/min by expression
JMESPath.search("max_by(people, &age).name", data) # => "bob"
JMESPath.search("min_by(people, &age).name", data) # => "alice"

# Map an expression over an array
JMESPath.search("map(&name, people)", data) # => ["bob", "alice"]
```


## Features

Full JMESPath specification support including:
- Basic field access
- Array indexing and slicing
- List and hash projections
- Filter expressions
- Multi-select hash and list
- Pipe expressions
- Literal values
- Comparisons and logical operators
- Expression references (`&expr`) for deferred evaluation
- 26 built-in functions: `abs`, `avg`, `ceil`, `contains`, `ends_with`, `floor`, `join`, `keys`, `length`, `map`, `max`, `max_by`, `merge`, `min`, `min_by`, `not_null`, `reverse`, `sort`, `sort_by`, `starts_with`, `sum`, `to_array`, `to_number`, `to_string`, `type`, `values`
- Informative error messages with expression context and caret pointing to the error position

## TODO

- Options Implementation: runtime configuration, custom function registration
- Caching System Improvements: cache size limits and eviction policies
- Performance Optimizations: benchmarking suite

## Development

Contributions are welcome! Please feel free to submit a Pull Request.

## Contributing

1. Fork it (<https://github.com/qequ/jmespath/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Alvaro Frias Garay](https://github.com/qequ) - creator and maintainer
