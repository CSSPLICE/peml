require_relative 'test_helper'
require 'minitest/mock'
require 'open-uri'

class UrlParseTest < Minitest::Test
  def test_parse_with_url
    url = "http://example.com/test.peml"
    peml_content = "exercise_id: test\ntitle: Test Exercise\nauthor: edwards@cs.vt.edu"
    
    # Mocking URI.open
    mock_io = Minitest::Mock.new
    mock_io.expect(:read, peml_content)
    
    URI.stub :open, mock_io do
      result = Peml.parse(url: url)
      assert_equal "Test Exercise", result[:value]["title"]
    end
    
    mock_io.verify
  end

  def test_parse_priority_filename_over_url
    filename = File.expand_path('../peml/01-minimal.peml', __FILE__)
    url = "http://example.com/test.peml"
    
    # filename has higher priority, should not call URI.open
    result = Peml.parse(filename: filename, url: url)
    assert_equal "A Minimal PEML Description", result[:value]["title"]
  end

  def test_parse_priority_url_over_peml
    url = "http://example.com/test.peml"
    peml_param = "title: PEML Param"
    url_content = "exercise_id: test\ntitle: URL Content\nauthor: edwards@cs.vt.edu"
    
    mock_io = Minitest::Mock.new
    mock_io.expect(:read, url_content)
    
    URI.stub :open, mock_io do
      result = Peml.parse(url: url, peml: peml_param)
      assert_equal "URL Content", result[:value]["title"]
    end
    
    mock_io.verify
  end
end
