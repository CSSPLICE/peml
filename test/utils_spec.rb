require 'test_helper'
require 'peml/utils'

describe Peml::Utils do

  describe ".mime_type" do

    # ----- Hash with explicit "type" key -----

    describe "when given a hash with a 'type' key" do
      it "returns the explicit type value" do
        _(Peml::Utils.mime_type({'type' => 'text/html'})).must_equal 'text/html'
      end

      it "returns the explicit type even if 'name' is also present" do
        hash = {'type' => 'application/json', 'name' => 'data.xml'}
        _(Peml::Utils.mime_type(hash)).must_equal 'application/json'
      end
    end

    # ----- Hash with "name" key (inferred from extension) -----

    describe "when given a hash with a 'name' key" do
      it "infers type from a .java extension" do
        _(Peml::Utils.mime_type({'name' => 'Main.java'})).must_equal 'text/x-java'
      end

      it "infers type from a .py extension" do
        _(Peml::Utils.mime_type({'name' => 'script.py'})).must_equal 'text/x-python'
      end

      it "infers type from a .rb extension" do
        _(Peml::Utils.mime_type({'name' => 'app.rb'})).must_equal 'text/x-ruby'
      end

      it "infers type from a .csv extension" do
        _(Peml::Utils.mime_type({'name' => 'data.csv'})).must_equal 'text/csv'
      end

      it "infers type from a .json extension" do
        _(Peml::Utils.mime_type({'name' => 'config.json'})).must_equal 'application/json'
      end

      it "is case-insensitive for extensions" do
        _(Peml::Utils.mime_type({'name' => 'Image.PNG'})).must_equal 'image/png'
      end

      it "returns nil for an unknown extension" do
        _(Peml::Utils.mime_type({'name' => 'file.xyz'})).must_be_nil
      end
    end

    # ----- String matching url(...) -----

    describe "when given a url(...) string" do
      it "infers type from the URL path extension" do
        _(Peml::Utils.mime_type('url(https://example.com/code/Main.py)')).must_equal 'text/x-python'
      end

      it "infers type from a URL with a .java path" do
        _(Peml::Utils.mime_type('url(https://example.com/src/App.java)')).must_equal 'text/x-java'
      end

      it "handles URLs with query parameters by using the path extension" do
        _(Peml::Utils.mime_type('url(https://example.com/file.html?v=1)')).must_equal 'text/html'
      end

      it "handles URLs with paths but no extension" do
        _(Peml::Utils.mime_type('url(https://example.com/api/data)')).must_be_nil
      end

      it "returns nil for an unknown URL extension" do
        _(Peml::Utils.mime_type('url(https://example.com/file.xyz)')).must_be_nil
      end
    end

    # ----- Edge cases -----

    describe "edge cases" do
      it "returns nil for a plain string that is not a url(...)" do
        _(Peml::Utils.mime_type('not_a_url')).must_be_nil
      end

      it "returns nil for an empty hash" do
        _(Peml::Utils.mime_type({})).must_be_nil
      end

      it "returns nil for nil input" do
        _(Peml::Utils.mime_type(nil)).must_be_nil
      end

      it "returns nil for a hash with neither 'type' nor 'name'" do
        _(Peml::Utils.mime_type({'content' => 'hello'})).must_be_nil
      end
    end
  end

  describe ".tabular_to_hashes" do
    it "converts a simple table to an array of hashes" do
      data = [
        ['name', 'age'],
        ['Alice', 30],
        ['Bob', 25]
      ]
      expected = [
        { 'name' => 'Alice', 'age' => 30 },
        { 'name' => 'Bob', 'age' => 25 }
      ]
      _(Peml::Utils.tabular_to_hashes(data)).must_equal expected
    end

    it "handles an empty table" do
      _(Peml::Utils.tabular_to_hashes([])).must_equal []
    end

    it "handles a table with only headers" do
      _(Peml::Utils.tabular_to_hashes([['name', 'age']])).must_equal []
    end

    it "handles mismatched row lengths (shorter rows)" do
      data = [
        ['name', 'age'],
        ['Alice']
      ]
      expected = [{ 'name' => 'Alice', 'age' => nil }]
      _(Peml::Utils.tabular_to_hashes(data)).must_equal expected
    end

    it "handles mismatched row lengths (longer rows)" do
      data = [
        ['name'],
        ['Alice', 30]
      ]
      expected = [{ 'name' => 'Alice' }]
      _(Peml::Utils.tabular_to_hashes(data)).must_equal expected
    end

    it "returns an empty array for nil input" do
      _(Peml::Utils.tabular_to_hashes(nil)).must_equal []
    end
  end

end
