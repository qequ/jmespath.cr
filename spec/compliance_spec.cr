require "./spec_helper"
require "json"

COMPLIANCE_DIR = File.join(__DIR__, "compliance")

# Load all compliance test suites from JSON files
def load_compliance_suites(file : String) : Array(JSON::Any)
  content = File.read(file)
  JSON.parse(content).as_a
end

# Compare two JSON::Any values for equality (handles ordering of object keys)
def json_equal?(actual : JSON::Any, expected : JSON::Any) : Bool
  actual.to_json == expected.to_json
end

COMPLIANCE_FILES = Dir.glob(File.join(COMPLIANCE_DIR, "*.json")).sort

describe "JMESPath compliance" do
  COMPLIANCE_FILES.each do |file|
    file_name = File.basename(file, ".json")

    # Skip benchmarks — they're performance tests, not correctness
    next if file_name == "benchmarks"

    describe file_name do
      suites = load_compliance_suites(file)

      suites.each_with_index do |suite, suite_idx|
        given = suite["given"]
        comment = suite["comment"]?.try(&.as_s) || "suite #{suite_idx}"
        cases = suite["cases"].as_a

        cases.each_with_index do |test_case, case_idx|
          expression = test_case["expression"].as_s
          has_result = test_case.as_h.has_key?("result")
          has_error = test_case.as_h.has_key?("error")
          case_comment = test_case["comment"]?.try(&.as_s)
          label = case_comment || expression
          # Truncate long expressions for readable test names
          label = label[0, 60] + "..." if label.size > 63

          if has_result
            it "#{comment}: #{label}" do
              expected = test_case["result"]
              begin
                actual = JMESPath.search(expression, given)
                json_equal?(actual, expected).should be_true,
                  "Expression: #{expression}\nExpected: #{expected.to_json}\n     Got: #{actual.to_json}"
              rescue ex
                fail "Expression: #{expression}\nUnexpected error: #{ex.message}"
              end
            end
          elsif has_error
            error_type = test_case["error"].as_s
            it "#{comment}: #{label} (expects #{error_type} error)" do
              expect_raises(Exception) do
                JMESPath.search(expression, given)
              end
            end
          end
        end
      end
    end
  end
end
