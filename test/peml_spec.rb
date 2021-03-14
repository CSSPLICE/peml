require 'test_helper'

describe Peml do

  describe "#load_file" do
    # Test that it successfully parses every positive example
    Dir.glob(File.expand_path('../peml/*.peml', __FILE__)).each do |f|
      slug = File.basename(f)

      it "parses #{slug}" do
        ex = Peml::parse(filename: f)
        _(ex).wont_be_nil
        _(ex[:value]).wont_be_nil
        _(ex[:diagnostics]).must_be_empty
      end
    end
  end

end
