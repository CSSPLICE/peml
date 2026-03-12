require 'test_helper'

# Golden File (Snapshot) Testing for the PEML Parser
#
# This test uses a "golden file" approach to verify functional correctness
# of the parser. For each .peml input in test/peml/, a corresponding .yaml
# file in test/peml/expected/ holds the expected output (both the parsed
# value and any diagnostics).
#
# Workflow:
#   bundle exec rake test
#     Compares parser output against golden files. Fails if output differs.
#
#   UPDATE_SNAPSHOTS=1 bundle exec rake test
#     Regenerates all golden files from the current parser output.
#     Review the generated YAML before committing to confirm correctness.
#
# Adding new test cases:
#   Drop a new .peml file in test/peml/, run with UPDATE_SNAPSHOTS=1 to
#   generate its golden file, review, and commit both files.

describe Peml do

  describe "#load_file" do
    expected_dir = File.expand_path('../peml/expected', __FILE__)
    Dir.mkdir(expected_dir) unless Dir.exist?(expected_dir)

    Dir.glob(File.expand_path('../peml/*.peml', __FILE__)).each do |f|
      slug = File.basename(f)

      it "parses #{slug}" do
        ex = Peml::parse(filename: f)
        _(ex).wont_be_nil

        golden = File.join(expected_dir, slug.sub('.peml', '.yaml'))
        actual_yaml = ex.to_yaml

        if ENV['UPDATE_SNAPSHOTS'] || !File.exist?(golden)
          File.write(golden, actual_yaml)
        end

        _(actual_yaml).must_equal File.read(golden)
      end
    end
  end

  describe "#load_file with render_tests: true" do
    expected_dir = File.expand_path('../peml/expected_render_tests', __FILE__)
    Dir.mkdir(expected_dir) unless Dir.exist?(expected_dir)

    Dir.glob(File.expand_path('../peml/*.peml', __FILE__)).each do |f|
      slug = File.basename(f)

      it "parses #{slug} and renders tests" do
        begin
          ex = Peml::parse(filename: f,
            render_tests: true,
            render_tests_params: { 'parse_descriptions' => true})
          _(ex).wont_be_nil

          golden = File.join(expected_dir, slug.sub('.peml', '.yaml'))
          actual_yaml = ex.to_yaml

          if ENV['UPDATE_SNAPSHOTS'] || !File.exist?(golden)
            File.write(golden, actual_yaml)
          end

          _(actual_yaml).must_equal File.read(golden)
        rescue Liquid::FileSystemError => e
          skip "Ignoring missing rendered templates for #{slug}: #{e.message}"
        end
      end
    end
  end

end
