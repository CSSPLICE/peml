require 'test_helper'

describe Peml do

  describe "#load_file" do
    # Test that it successfully parses every positive example
    Dir.glob(File.expand_path('../peml/*.peml', __FILE__)).each do |f|
      slug = File.basename(f)

      it "parses #{slug}" do
        Peml::load_file(f).wont_be_nil
      end
    end
  end

end
