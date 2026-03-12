require_relative 'test_helper'
require 'minitest/mock'
require 'open-uri'

describe 'URL Parse Test' do
  it 'parses with a URL' do
    url = "http://example.com/test.peml"
    peml_content = "exercise_id: test\ntitle: Test Exercise\nauthor: edwards@cs.vt.edu"
    
    mock_io = Minitest::Mock.new
    mock_io.expect(:read, peml_content)
    
    URI.stub :open, mock_io do
      result = Peml.parse(url: url)
      _(result['value']["title"]).must_equal "Test Exercise"
    end
    
    mock_io.verify
  end

  it 'prioritizes filename over URL' do
    filename = File.expand_path('../peml/01-minimal.peml', __FILE__)
    url = "http://example.com/test.peml"
    
    # URI.open should not be called since filename takes precedence
    bad_open = lambda { |*args| raise "URI.open should not be called" }
    
    URI.stub :open, bad_open do
      result = Peml.parse(filename: filename, url: url)
      _(result['value']["title"]).must_equal "A Minimal PEML Description"
    end
  end

  it 'prioritizes URL over PEML param' do
    url = "http://example.com/test.peml"
    peml_param = "title: PEML Param"
    url_content = "exercise_id: test\ntitle: URL Content\nauthor: edwards@cs.vt.edu"
    
    mock_io = Minitest::Mock.new
    mock_io.expect(:read, url_content)
    
    URI.stub :open, mock_io do
      result = Peml.parse(url: url, peml: peml_param)
      _(result['value']["title"]).must_equal "URL Content"
    end
    
    mock_io.verify
  end
end
