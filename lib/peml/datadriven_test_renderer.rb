
require_relative 'csv_unquoted_parser'
require 'dottie/ext'
require 'csv'
require 'liquid'
require 'pp'

# need to fix pattern.actual
module Peml
  class DatadrivenTestRenderer

    # points to the directory where the liquid templates are saved
    @@template_path = File.expand_path('templates/', __dir__) + "/"


    # -------------------------------------------------------------
    def render_datadriven_tests!(state, options = {})
      peml = state['value']
      if (peml.key?('systems'))
        peml['systems'].each do |system|
          if (system.key?('language'))
            language = system['language']
            if language
                language = language.downcase
                if language == 'c++'
                  language = 'cpp'
                end
            end
            default_patterns = {}
            if options.key?('pattern')
              default_patterns = options['pattern']
            end
            if options.key?(language) && options[language].key?('pattern')
              default_patterns = default_patterns.merge(options[language]['pattern'])
            end
            if system.key?('assets') &&
              system['assets'].key?('test') &&
              system['assets']['test'].key?('files')
              system['assets']['test']['files'].each do |file|
                if file['type'] == 'inline'
                  patterns = default_patterns.merge(file['pattern'] || {})
                  test_cases = { 'test_cases' => file['content'] }
                  columns = {}
                  if file.key?('columns')
                    columns = columns.merge(file['columns'])
                  end
                  if options['parse_descriptions']
                    test_cases['test_cases'].each do |test_case|
                      while (description = test_case['description']) &&
                            (match = description.match(/^\s*(example|hidden|screening)\s*(?::\s*(.*)|$)\s*$/i))
                        test_case[match[1].downcase] = true
                        test_case['description'] = (match[2] || "").strip
                      end
                      test_case.delete('description') if test_case['description'].to_s.empty?
                    end
                  end
                  # convert column values where needed
                  test_cases['test_cases'].each do |test_case|
                    new_keys = {}
                    test_case.each do |key, value|
                      if columns.key?(key)
                        if columns[key].key?('format') && columns[key]['format'] == 'yaml'
                          new_keys[key + '__as_yaml'] = value
                        end
                        test_case[key] = Utils.render_prog_literal(value, language, columns[key])
                      end
                    end
                    test_case.merge!(new_keys)
                  end
                  resolver = PemlTemplateResolver.new(patterns, language)
                  template_source = resolver.read_template_file('test_class')
                  template_class = Liquid::Template.parse(template_source, :error_mode => :strict)
                  context = PemlContext.new(
                    test_cases,
                    {},
                    { file_system: resolver, use_raw_yaml: 0 },
                    true)
                  file['content'] = template_class.render(context)
                  if !template_class.errors.empty? && state['diagnostics']
                    template_class.errors.each do |err|
                      state['diagnostics'] << "Template error: #{err.message}"
                    end
                  end
                  file['type'] = "text/x-#{language}"
                end
              end
            end
          end
        end
      end
      state
    end
  end


  # -------------------------------------------------------------
  class PemlInclude < Liquid::Include
    def initialize(tag_name, markup, options)
      @mysig = "#{tag_name} #{markup}"
      @for_idx = 0
      super
    end

    def render_to_output_buffer(context, output)
      @for_idx += 1
      extra_scope = { 'for_idx' => @for_idx }
      # puts "render_to_output_buffer: #{@mysig} #{@for_id}"
      if @attributes.key?('flatten')
        extra_scope.merge!(@attributes['flatten'].evaluate(context))
      end
      context.stack(extra_scope) do
        super
      end
    end
  end


  # -------------------------------------------------------------
  class ShowYaml < Liquid::Block
    def render(context)
      context.registers[:use_raw_yaml] = context.registers[:use_raw_yaml].to_i + 1
      result = super
      context.registers[:use_raw_yaml] = context.registers[:use_raw_yaml].to_i - 1
      result
    end
  end


  # -------------------------------------------------------------
  class PemlContext < Liquid::Context
    def find_variable(key, *args)
      if registers[:use_raw_yaml].to_i > 0 && key.is_a?(String) && !key.end_with?('__as_yaml')
        yaml_key = "#{key}__as_yaml"
        val = super(yaml_key, *args)
        return val unless val.nil?
      end
      super
    end
  end


  # -------------------------------------------------------------
  class PemlTemplateResolver
    def initialize(programmatic_definitions, language)
      @overrides = programmatic_definitions
      @base_path = File.expand_path("templates/", __dir__)
      @base_lang_path = File.expand_path("templates/#{language.downcase}/", __dir__)
    end

    def read_template_file(template_path)
      # 1. Check programmatic overrides first (precedence)
      return @overrides[template_path].strip if @overrides.key?(template_path)

      # 2. Fall back to language specific base templates on disk
      file_path = File.join(@base_lang_path, "#{template_path}.liquid")
      return File.read(file_path).strip if File.exist?(file_path)

      # 3. Fall back to standard base templates on disk
      file_path = File.join(@base_path, "#{template_path}.liquid")
      return File.read(file_path).strip if File.exist?(file_path)

      raise Liquid::FileSystemError, "No such template '#{template_path}'"
    end
  end

  # -------------------------------------------------------------
  module PemlFilters
    def string_literal(input)
      val = input.to_s
      return val if val.start_with?('"')

      # Escape any embedded backslashes and double-quotes
      escaped = val.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
      "\"#{escaped}\""
    end
  end


  # -------------------------------------------------------------
  Liquid::Template.register_tag('include', PemlInclude)
  Liquid::Template.register_tag('show_yaml', ShowYaml)
  Liquid::Template.register_filter(PemlFilters)
end
