require 'test_helper'

class PemlTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Peml::VERSION
  end
end
