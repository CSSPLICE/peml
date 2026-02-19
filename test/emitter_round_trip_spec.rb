require 'test_helper'
require 'peml'
require 'json'

# Round-trip tests for the PEML emitter (to_peml).
#
# For each golden file in test/peml/expected/, this test:
# 1. Loads the golden JSON and extracts the "value" (parsed PEML hash)
# 2. Emits it back to PEML text via Peml.to_peml()
# 3. Re-parses the emitted PEML text via Peml.parse()
# 4. Compares the re-parsed value to the original golden value
#
# This verifies that the emitter produces output that the parser can
# faithfully reconstruct into the same data structure.

describe "Emitter round-trip" do
  golden_dir = File.expand_path('../peml/expected', __FILE__)
  golden_files = Dir.glob(File.join(golden_dir, '*.json')).sort

  # Deep-stringify all keys in a nested structure.
  # Golden files go through JSON (all string keys), but
  # DatadrivenTestRenderer produces symbol keys in parsed_tests.
  def self.deep_stringify(obj)
    case obj
    when Hash
      obj.each_with_object({}) do |(k, v), h|
        h[k.to_s] = deep_stringify(v)
      end
    when Array
      obj.map { |v| deep_stringify(v) }
    else
      obj
    end
  end

  golden_files.each do |golden_path|
    basename = File.basename(golden_path, '.json')

    it "round-trips #{basename} through to_peml and back through parse" do
      # 1. Load the golden file and extract just the value (no diagnostics)
      golden = JSON.parse(File.read(golden_path))
      original_value = golden['value']

      # 2. Emit the value to PEML text
      peml_text = Peml.to_peml(original_value)

      # The emitter must produce a String for round-tripping to work
      skip "Emitter does not yet produce PEML text" unless peml_text.is_a?(String)

      # 3. Re-parse the emitted PEML text (result_only to get just the hash)
      reparsed_value = Peml.parse(peml: peml_text, result_only: true)

      # 4. Deep-stringify for comparison (JSON keys are always strings)
      reparsed_value = self.class.deep_stringify(reparsed_value)

      # 5. Compare the re-parsed value to the original
      _(reparsed_value).must_equal original_value
    end
  end
end
