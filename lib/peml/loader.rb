require 'peml/version'

module Peml
  class Loader

    #~ Constants ...............................................................

    WHITESPACE_PATTERN = "\u0000\u0009\u000A\u000B\u000C\u000D\u0020\u00A0\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u200B\u2028\u2029\u202F\u205F\u3000\uFEFF"
    SLUG_BLACKLIST     = "#{WHITESPACE_PATTERN}\u005B\u005C\u005D\u007B\u007D\u003A"

    START_KEY     = /^([^#{Regexp.escape(SLUG_BLACKLIST)}]+)[ \t\r]*:(((\S)\4{2,})|[ \t\r]*)(.*(?:\n|\r|$))/
    COMMENT_LINE  = /^\s*(#.*(?:\n|\r|$))/
    COMMAND_KEY   = /^:[ \t\r]*(endskip|ignore|skip|end)(.*(?:\n|\r|$))/i
    ARRAY_ELEMENT = /^\s*\*[ \t\r]*(.*(?:\n|\r|$))/
    SCOPE_PATTERN = /^(\[|\{)[ \t\r]*([\+\.]*)[ \t\r]*([^#{Regexp.escape(SLUG_BLACKLIST)}]*)[ \t\r]*(?:\]|\}).*?(\n|\r|$)/


    #~ Public instance methods .................................................

    # -------------------------------------------------------------
    def initialize(options = {})
      @data = @scope = {}

      @stack = []
      @stack_scope = nil

      @buffer_scope = @buffer_key = nil
      @buffer_string = ''
      @quote_string = ''

      @is_skipping = false
      @is_quoted = false
      @done_parsing = false
      @depth = 0

      @default_options = {
          comments: false
      }.merge(options)
    end


    # -------------------------------------------------------------
    def load(stream, options = {})
      @options = @default_options.merge(options)

      stream.each_line do |line|
        return @data if @done_parsing

        if @is_quoted
          if line.match(/^#{@quote_string}(?:\n|\r|$)/)
            # end quote
            self.parse_command_key('end')
            @is_quoted = false
            @quote_string = ''
          else
            self.parse_text(line)
          end

        elsif match = line.match(COMMENT_LINE)
          # just skip it!

        elsif match = line.match(COMMAND_KEY)
          self.parse_command_key(match[1].downcase)

        elsif @skipping
          # should we just ignore this text, instead of parsing it?
          self.parse_text(line)

        elsif (match = line.match(START_KEY)) &&
            (!@stack_scope || @stack_scope[:array_type] != :simple)
          self.parse_start_key(match[1], match[3], match[5] || '')

        elsif (match = line.match(ARRAY_ELEMENT)) && @stack_scope &&
          @stack_scope[:array] && (@stack_scope[:array_type] != :complex ) &&
          !@stack_scope[:flags].match(/\+/)
          self.parse_array_element(match[1])

        elsif match = line.match(SCOPE_PATTERN)
          self.parse_scope(match[1], match[2], match[3])

        else
          # just plain text
          self.parse_text(line)
        end
      end

      # Treat all keys as multi-line
      self.parse_command_key('end')

      self.flush_buffer!
      return @data
    end


    # -------------------------------------------------------------
    def parse_start_key(key, quote, rest_of_line)
      # Treat all keys as multi-line
      self.parse_command_key('end')

      self.flush_buffer!

      self.increment_array_element(key)

      key = 'value' if (@stack_scope && @stack_scope[:flags].match(/\+/))

      @buffer_key = key
      @buffer_string = rest_of_line

      self.flush_buffer_into(key, replace: true)

      if !quote.nil?
        @is_quoted = true
        @quote_string = quote
      end
    end


    # -------------------------------------------------------------
    def parse_array_element(value)
      # Treat all keys as multi-line
      self.parse_command_key('end')

      self.flush_buffer!

      @stack_scope[:array_type] ||= :simple

      @stack_scope[:array] << ''
      @buffer_key = @stack_scope[:array]
      @buffer_string = value
      self.flush_buffer_into(@stack_scope[:array], replace: true)
    end


    # -------------------------------------------------------------
    def parse_command_key(command)
      if @is_skipping && !%w(endskip ignore).include?(command)
        return self.flush_buffer!
      end

      case command
        when "end"
          self.flush_buffer_into(@buffer_key, replace: false) if @buffer_key
          @buffer_key = nil
          return

        when "ignore"
          # If this occurs in the middle of a multi-line value, save what
          # has been accumulated so far
          self.flush_buffer_into(@buffer_key, replace: false) if @buffer_key
          return @done_parsing = true

        when "skip"
          # If this occurs in the middle of a multi-line value, save what
          # has been accumulated so far
          self.flush_buffer_into(@buffer_key, replace: false) if @buffer_key
          @is_skipping = true

        when "endskip"
          @is_skipping = false
      end

      self.flush_buffer!
    end


    # -------------------------------------------------------------
    def parse_scope(scope_type, flags, scope_key)
      # Treat all keys as multi-line
      self.parse_command_key('end')

      self.flush_buffer!

      if scope_key == ''
        last_stack_item = @stack.pop
        @scope = (last_stack_item ? last_stack_item[:scope] : @data) || @data
        @stack_scope = @stack.last

      elsif %w([ {).include?(scope_type)
        nesting = false
        key_scope = @data

        if flags.match(/^\./)
          self.increment_array_element(scope_key)
          nesting = true
          key_scope = @scope if @stack_scope
        else
          @scope = @data
          @stack = []
        end

        # Within freeforms, the `type` of nested objects and arrays is taken
        # verbatim from the `keyScope`.
        if @stack_scope && @stack_scope[:flags].match(/\+/)
          parsed_scope_key = scope_key

          # Outside of freeforms, dot-notation interpreted as nested data.
        else
          key_bits = scope_key.split('.')
          key_bits[0...-1].each do |bit|
            key_scope = key_scope[bit] ||= {}
          end
          parsed_scope_key = key_bits.last
        end

        # Content of nested scopes within a freeform should be stored under "value."
        if (@stack_scope && @stack_scope[:flags].match(/\+/) && flags.match(/\./))
          if scope_type == '['
            parsed_scope_key = 'value'
          elsif scope_type == '{'
            @scope = @scope[:value] = {}
          end
        end

        stack_scope_item = {
            array: nil,
            array_type: nil,
            array_first_key: nil,
            flags: flags,
            scope: @scope
        }
        if scope_type == '['
          stack_scope_item[:array] = key_scope[parsed_scope_key] = []
          stack_scope_item[:array_type] = :freeform if flags.match(/\+/)
          if nesting
            @stack << stack_scope_item
          else
            @stack = [stack_scope_item]
          end
          @stack_scope = @stack.last

        elsif scope_type == '{'
          if nesting
            @stack << stack_scope_item
          else
            @scope = key_scope[parsed_scope_key] = key_scope[parsed_scope_key].is_a?(Hash) ? key_scope[parsed_scope_key] : {}
            @stack = [stack_scope_item]
          end
          @stack_scope = @stack.last
        end
      end
    end


    # -------------------------------------------------------------
    def parse_text(text)
      if @stack_scope && @stack_scope[:flags].match(/\+/) && text.match(/[^\n\r\s]/)
        @stack_scope[:array] << { "type" => "text", "value" => text.gsub(/(^\s*)|(\s*$)/, '') }
      else
        @buffer_string += text
      end
    end


    # -------------------------------------------------------------
    def increment_array_element(key)
      # Special handling for arrays. If this is the start of the array, remember
      # which key was encountered first. If this is a duplicate encounter of
      # that key, start a new object.

      if @stack_scope && @stack_scope[:array]
        # If we're within a simple array, ignore
        @stack_scope[:array_type] ||= :complex
        return if @stack_scope[:array_type] == :simple

        # array_first_key may be either another key, or nil
        if @stack_scope[:array_first_key] == nil || @stack_scope[:array_first_key] == key
          @stack_scope[:array] << (@scope = {})
        end
        if (@stack_scope[:flags].match(/\+/))
          @scope[:type] = key
          # key = 'content'
        else
          @stack_scope[:array_first_key] ||= key
        end
      end
    end


    # -------------------------------------------------------------
    def flush_buffer!
      result = @buffer_string.dup
      puts "    flushed content = #{result.inspect}"
      @buffer_string = ''
      @buffer_key = nil
      return result
    end


    # -------------------------------------------------------------
    def flush_buffer_into(key, options = {})
      existing_buffer_key = @buffer_key
      value = self.flush_buffer!

      if options[:replace]
        if @is_quoted
          @buffer_string = value
        else
          value = self.format_value(value, :replace).sub(/^\s*/, '')
          @buffer_string = value.match(/\s*\Z/)[0]
        end
        @buffer_key = existing_buffer_key
      else
        value = self.format_value(value, :append)
      end
      if !@is_quoted
        value = value.sub(/\s*\Z/, '')
      end
      puts "    flushed content = #{value.inspect}"

      if key.class == Array
        key[key.length - 1] = '' if options[:replace]
        key[key.length - 1] += value

      else
        key_bits = key.split('.')
        @buffer_scope = @scope

        key_bits[0...-1].each do |bit|
          @buffer_scope[bit] = {} if @buffer_scope[bit].class == String # reset
          @buffer_scope = @buffer_scope[bit] ||= {}
        end

        @buffer_scope[key_bits.last] = '' if options[:replace]
        @buffer_scope[key_bits.last] += value
      end
    end


    # -------------------------------------------------------------
    # type can be either :replace or :append.
    # If it's :replace, then the string is assumed to be the first line of a
    # value, and no escaping takes place.
    # If we're appending to a multi-line string, escape special punctuation
    # by prepending the line with a backslash.
    # (:, [, {, *, \) surrounding the first token of any line.
    def format_value(value, type)
      # backslash-escaped leading characters have been removed in favor of
      # quoted values.
      #
      # if type == :append
      #  value.gsub!(/^(\s*)\\/, '\1')
      # end

      # puts "    after formatting = #{value.inspect}"
      value
    end

  end
end
