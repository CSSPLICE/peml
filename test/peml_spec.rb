require 'test_helper'

schema = JSONSchemer.schema(File.expand_path('../peml/PEML.json', __FILE__))

describe Peml do

  describe "#load_file" do
    # Test that it successfully parses every positive example
    Dir.glob(File.expand_path('../peml/*.peml', __FILE__)).each do |f|
      slug = File.basename(f)

      it "parses #{slug}" do
        ex = Peml::load_file(f)
        ex.wont_be_nil
        schema.validate(ex).to_a.must_be_empty
      end
    end
  end

end
