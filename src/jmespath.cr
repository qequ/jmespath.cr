require "json"
require "./lexer"
require "./exceptions"
require "./ast"
require "./parser"
require "./visitor"
require "./parsed_result"

module JMESPath
  VERSION = "0.1.0"

  # Main entry point for JMESPath expressions
  #
  # @param expression [String] A valid JMESPath expression
  # @param data [JSON::Any] The data to search
  # @param options [Hash] Optional runtime configuration
  # @return [JSON::Any] Returns the matched values or nil if not found
  def self.search(expression : String,
                  data : JSON::Any | Hash(String, JSON::Any) | String | IO,
                  options = nil) : JSON::Any
    # Convert input data to JSON::Any if needed
    json_data = case data
                when JSON::Any
                  data
                when Hash(String, JSON::Any)
                  JSON::Any.new(data)
                when String
                  JSON.parse(data)
                when IO
                  JSON.parse(data.gets_to_end)
                else
                  raise ArgumentError.new("Invalid data type: #{data.class}")
                end

    # Create parser and parse expression
    parser = Parser.new
    parsed = parser.parse(expression)

    # Search the data using the parsed expression
    parsed.search(json_data)
  end
end
