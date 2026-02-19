require 'test_helper'
require 'peml'
require 'yaml'
require 'json'
require 'csv'
require 'rexml/document'

describe 'Peml.inline_data_files' do

  it 'inlines YAML content' do
    peml = {
      'file' => {
        'name' => 'data.yaml',
        'content' => "key: value\nlist:\n  - 1\n  - 2"
      }
    }
    result = Peml.inline_data_files(peml)
    _(result['file']['content']).must_equal({ 'key' => 'value', 'list' => [1, 2] })
  end

  it 'inlines JSON content' do
    peml = {
      'file' => {
        'name' => 'data.json',
        'content' => '{"foo": "bar", "num": 123}'
      }
    }
    result = Peml.inline_data_files(peml)
    _(result['file']['content']).must_equal({ 'foo' => 'bar', 'num' => 123 })
  end

  it 'inlines CSV content' do
    peml = {
      'file' => {
        'name' => 'data.csv',
        'content' => "a,b,c\n1,2,3"
      }
    }
    result = Peml.inline_data_files(peml)
    _(result['file']['content']).must_equal([{ 'a' => '1', 'b' => '2', 'c' => '3' }])
  end

  it 'inlines XML content' do
    peml = {
      'file' => {
        'name' => 'data.xml',
        'content' => '<root><item id="1">Text</item></root>'
      }
    }
    result = Peml.inline_data_files(peml)
    _(result['file']['content']).must_equal({ 'item' => { '@id' => '1', 'content' => 'Text' } })
  end

  it 'inlines values in a "files" array' do
    peml = {
      'files' => [
        { 'name' => 'a.json', 'content' => '{"id": 1}' },
        { 'name' => 'b.yaml', 'content' => 'id: 2' }
      ]
    }
    result = Peml.inline_data_files(peml)
    _(result['files'][0]['content']).must_equal({ 'id' => 1 })
    _(result['files'][1]['content']).must_equal({ 'id' => 2 })
  end

  it 'recursively inlines data files' do
    peml = {
      'systems' => [
        {
          'id' => 'sys1',
          'files' => [
            { 'name' => 'config.yaml', 'content' => 'port: 8080' }
          ]
        }
      ],
      'assessment' => {
        'file' => { 'name' => 'suite.json', 'content' => '[{"test": "ok"}]' }
      }
    }
    result = Peml.inline_data_files(peml)
    _(result['systems'][0]['files'][0]['content']).must_equal({ 'port' => 8080 })
    _(result['assessment']['file']['content']).must_equal([{ 'test' => 'ok' }])
  end

  it 'handles multiple calls to inline_data_file safely' do
    peml = {
      'file' => { 'name' => 'data.json', 'content' => '{"a": 1}' }
    }
    result = Peml.inline_data_files(peml)
    # Ensure second call doesn't crash (content is already a hash)
    result2 = Peml.inline_data_files(result)
    _(result2['file']['content']).must_equal({ 'a' => 1 })
  end

  it 'skips files with unknown formats' do
    peml = {
      'file' => { 'name' => 'data.txt', 'content' => 'Plain text' }
    }
    result = Peml.inline_data_files(peml)
    _(result['file']['content']).must_equal 'Plain text'
  end

  it 'handles unquoted-csv content' do
    peml = {
      'file' => {
        'name' => 'data.ucsv',
        'content' => "a, b, c\nx, y, z"
      }
    }
    result = Peml.inline_data_files(peml)
    # CsvUnquotedParser returns an array of arrays (lines of cells),
    # which tabular_to_hashes converts to an array of hashes.
    _(result['file']['content']).must_equal [{ 'a' => 'x', 'b' => 'y', 'c' => 'z' }]
  end

end
