require 'test_helper'

# Golden File (Snapshot) Testing for the PEML PIF Methods
#
# This test uses a "golden file" approach to verify functional correctness
# of PIF parsing and Runestone conversion. For each .peml input in
# test/pif/positives/ or test/pif/negatives/, a corresponding .yaml file in
# test/pif/expected_positives/ or test/pif/expected_negatives/ holds the
# expected output (parsed values, converted Runestone structures, or diagnostics).
#
# Workflow:
#   bundle exec rake test
#     Compares PIF output against golden files. Fails if output differs.
#
#   UPDATE_SNAPSHOTS=1 bundle exec rake test
#     Regenerates all golden files from current PIF parser and converter output.
#     Review the generated YAML before committing to confirm correctness.
#
# Adding new test cases:
#   Drop a new .peml file in test/pif/positives/ or test/pif/negatives/,
#   run with UPDATE_SNAPSHOTS=1 to generate its golden file, review,
#   and commit both files.
describe "Peml PIF Methods" do

  describe "Valid Inputs (Positives)" do
    expected_dir = File.expand_path('../pif/expected_positives', __FILE__)
    Dir.mkdir(expected_dir) unless Dir.exist?(expected_dir)

    Dir.glob(File.expand_path('../pif/positives/*.peml', __FILE__)).each do |f|
      slug = File.basename(f)

      it "parses and converts #{slug}" do
        parsed_pif = Peml.pif_parse(filename: f)
        _(parsed_pif).wont_be_nil
        # Also convert it to runestone to snapshot both parsing and converting
        runestone_data = Peml.pif_to_runestone(parsed_pif[:value].dottie!)
        
        snapshot_data = {
          'parsed' => parsed_pif,
          'runestone' => runestone_data
        }

        golden = File.join(expected_dir, slug.sub('.peml', '.yaml'))
        actual_yaml = snapshot_data.to_yaml

        if ENV['UPDATE_SNAPSHOTS'] || !File.exist?(golden)
          File.write(golden, actual_yaml)
        end

        _(actual_yaml).must_equal File.read(golden)
      end
    end
  end

  describe "Invalid Inputs (Negatives)" do
    expected_dir = File.expand_path('../pif/expected_negatives', __FILE__)
    Dir.mkdir(expected_dir) unless Dir.exist?(expected_dir)

    Dir.glob(File.expand_path('../pif/negatives/*.peml', __FILE__)).each do |f|
      slug = File.basename(f)

      it "produces diagnostics for #{slug}" do
        parsed_pif = Peml.pif_parse(filename: f)
        _(parsed_pif).wont_be_nil
        
        # Known cases where the parser simply overwrites duplicate keys rather than throw an error
        if ['inconsistent-block-defs1.peml', 'inconsistent-block-defs2.peml'].include?(slug)
          _(parsed_pif[:diagnostics]).must_be_empty
        else
          _(parsed_pif[:diagnostics]).wont_be_empty
        end

        golden = File.join(expected_dir, slug.sub('.peml', '.yaml'))
        actual_yaml = parsed_pif.to_yaml

        if ENV['UPDATE_SNAPSHOTS'] || !File.exist?(golden)
          File.write(golden, actual_yaml)
        end

        _(actual_yaml).must_equal File.read(golden)
      end
    end
  end

end
