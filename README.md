# JMESPath.cr

A Crystal implementation of [JMESPath](https://jmespath.org/), a query language for JSON. JMESPath allows you to declaratively extract elements from complex JSON documents.

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

## Features

The library supports most JMESPath expressions including:
- Basic field access
- Array indexing and slicing
- List and hash projections
- Filter expressions
- Multi-select hash and list
- Pipe expressions
- Literal values
- Comparisons and logical operators

## TODO

The following features are still pending implementation:

1. Built-in Functions
   - No built-in functions are currently implemented
   - Need to add support for string, array, number manipulation functions

2. Expression References (expref)
   - The `&` operator for function references is not implemented

3. JMESPath Compliance
   - Need to implement comprehensive compliance test suite
   - Verify behavior matches official JMESPath specification

4. Options Implementation
   - Add support for runtime configuration options
   - Implementation of custom function registration

5. Caching System Improvements
   - Current basic caching system for parsed expressions
   - Need to add cache size limits and eviction policies

6. Performance Optimizations
   - Optimize parser for large expressions
   - Add benchmarking suite

7. Error Handling Improvements
   - More detailed error messages
   - Better error recovery strategies

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
