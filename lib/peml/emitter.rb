module Peml
  class Emitter
    #~ Public instance methods .................................................

    # -------------------------------------------------------------
    def initialize(options = {})

    end

    # -------------------------------------------------------------
    def emit(value)
      accumulator = []
      to_leaf(accumulator, [], value)
      return leaves_to_peml(accumulator)
    end

    private
    #~ Private instance methods ................................................

    # -------------------------------------------------------------
    def to_leaf(accumulator, path, obj)
      case obj
      when Hash
        obj.each do |key, value|
          path.push(key)
          to_leaf(accumulator, path, value)
          path.pop
        end
      when Array
        key = path.pop
        path.push([ key ])
        obj.each do |value|
          to_leaf(accumulator, path, value)
        end
        key = path.pop
        path.push(key[0])
      else
        accumulator.push({ path: path.clone, value: obj })
      end
    end

    # -------------------------------------------------------------
    def leaves_to_peml(leaves)
      return leaves
    end

  end
end
