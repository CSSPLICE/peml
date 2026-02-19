module Peml
  class Emitter

    HEREDOC_DELIMITER = '----------'

    #~ Public instance methods .................................................

    # -------------------------------------------------------------
    def initialize(options = {})
    end

    # -------------------------------------------------------------
    # Emit a nested Hash/Array data structure as PEML text.
    def emit(value)
      lines = []
      emit_hash(lines, [], value, in_array: false)
      lines.join("\n") + "\n"
    end

    # -------------------------------------------------------------
    # Walk a Hash, emitting each key-value pair.
    # prefix is an Array of ancestor key strings for dotted notation.
    # in_array indicates we're inside an array element (for [.key] notation).
    def emit_hash(lines, prefix, hash, in_array: false)
      hash.each do |key, value|
        emit_value(lines, prefix, key, value, in_array: in_array)
      end
    end

    # -------------------------------------------------------------
    # Route a value to the appropriate emitter based on its type.
    def emit_value(lines, prefix, key, value, in_array: false)
      case value
      when Hash
        emit_hash(lines, prefix + [key], value, in_array: in_array)
      when Array
        emit_array(lines, prefix, key, value, nested: in_array)
      else
        emit_string(lines, prefix, key, value.to_s)
      end
    end

    # -------------------------------------------------------------
    # Emit a scalar string value as a PEML key-value line.
    # Uses heredoc quoting for multi-line values.
    def emit_string(lines, prefix, key, str)
      full_key = dotted(prefix, key)
      if needs_quoting?(str)
        lines << "#{full_key}:#{HEREDOC_DELIMITER}"
        lines << str.chomp
        lines << HEREDOC_DELIMITER
      else
        lines << "#{full_key}: #{str}"
      end
    end

    # -------------------------------------------------------------
    # Emit an Array using [scope] ... [] notation.
    # When nested is true, uses [.key] instead of [key].
    def emit_array(lines, prefix, key, array, nested: false)
      scope_key = dotted(prefix, key)
      dot_prefix = nested ? '.' : ''
      lines << "[#{dot_prefix}#{scope_key}]"
      array.each do |element|
        if element.is_a?(Hash)
          emit_hash(lines, [], element, in_array: true)
        else
          # Simple array elements (strings) — use * notation
          lines << "* #{element}"
        end
      end
      lines << "[]"
    end

    # -------------------------------------------------------------
    # Join a prefix array and a key into dotted notation.
    # e.g., dotted(["license", "owner"], "name") => "license.owner.name"
    def dotted(prefix, key)
      (prefix + [key]).join('.')
    end

    # -------------------------------------------------------------
    # Determine if a string needs heredoc quoting.
    # True if the string contains newlines or has leading whitespace
    # (the parser trims leading/trailing whitespace from non-heredoc values).
    def needs_quoting?(str)
      str.include?("\n") || str.match?(/\A\s/)
    end

  end
end
