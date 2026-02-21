
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
    def render_datadriven_tests!(peml, options = {})
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
                patterns = default_patterns.merge(file['pattern'] || {})
                test_cases = { 'test_cases' => file['content'] }
                resolver = PemlTemplateResolver.new(patterns, language)
                template_source = resolver.read_template_file('test_class')
                template_class = Liquid::Template.parse(template_source, :error_mode => :strict)
                file['content'] = template_class.render(
                  test_cases,
                  registers: { file_system: resolver }
                )
              end
            end
          end
        end
      end
      peml
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

  Liquid::Template.register_tag('include', PemlInclude)
end

