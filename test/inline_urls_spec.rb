require_relative 'test_helper'
require 'minitest/mock'
require 'open-uri'

describe 'Inline URLs Test' do
  it 'inlines raw content from a URL' do
    url = "http://example.com/data.txt"
    content = "This is the content from the URL."
    peml = { "description" => "url(#{url})" }
    
    mock_io = Minitest::Mock.new
    mock_io.expect(:read, content)
    
    URI.stub :open, mock_io do
      result = Peml.inline_urls(peml)
      _(result["description"]).must_equal content
    end
    
    mock_io.verify
  end

  it 'ignores strings that are not url(...) headers' do
    peml = { "description" => "Just a normal string", "other" => "Not a url(http://test.com) either" }
    result = Peml.inline_urls(peml)
    _(result["description"]).must_equal "Just a normal string"
    _(result["other"]).must_equal "Not a url(http://test.com) either"
  end

  it 'handles URL opening failures by returning original value' do
    url = "http://example.com/fail.txt"
    peml = { "description" => "url(#{url})" }
    
    URI.stub :open, ->(u) { raise "Connection failed" } do
      result = Peml.inline_urls(peml)
      _(result["description"]).must_equal "url(#{url})"
    end
  end

  it 'recursively inlines URLs in nested structures' do
    url1 = "http://example.com/1.txt"
    url2 = "http://example.com/2.txt"
    content1 = "Content 1"
    content2 = "Content 2"
    
    peml = {
      "level1" => {
        "item1" => "url(#{url1})",
        "level2" => [
          { "item2" => "url(#{url2})" },
          "plain text"
        ]
      }
    }
    
    mock_io1 = Minitest::Mock.new
    mock_io1.expect(:read, content1)
    
    mock_io2 = Minitest::Mock.new
    mock_io2.expect(:read, content2)
    
    # We need a stub that can handle multiple different calls
    stub_open = lambda do |url|
      if url == url1
        mock_io1
      elsif url == url2
        mock_io2
      else
        raise "Unexpected URL: #{url}"
      end
    end
    
    URI.stub :open, stub_open do
      result = Peml.inline_urls(peml)
      _(result["level1"]["item1"]).must_equal content1
      _(result["level1"]["level2"][0]["item2"]).must_equal content2
      _(result["level1"]["level2"][1]).must_equal "plain text"
    end
    
    mock_io1.verify
    mock_io2.verify
  end

  it 'is triggered correctly by Peml.parse params' do
    url = "http://example.com/data.txt"
    content = "Inlined Content"
    input = "exercise_id: test\ndescription: url(#{url})"
    
    mock_io = Minitest::Mock.new
    mock_io.expect(:read, content)
    
    URI.stub :open, mock_io do
      result = Peml.parse(peml: input, inline_urls: true)
      _(result['value']["description"]).must_equal content
    end
    
    mock_io.verify
  end
end
