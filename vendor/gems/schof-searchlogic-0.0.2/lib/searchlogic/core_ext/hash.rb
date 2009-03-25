module Searchlogic
  module CoreExt # :nodoc: all
    module Hash
      def deep_dup
        new_hash = {}
        
        self.each do |k, v|
          case v
          when Hash
            new_hash[k] = v.deep_dup
          else
            new_hash[k] = v
          end
        end
        
        new_hash
      end
      
      def deep_delete_duplicate_keys(hash)
        hash.each do |k, v|
          if v.is_a?(Hash) && self[k]
            self[k].deep_delete_duplicate_keys(v)
            delete(k) if self[k].blank?
          else
            delete(k)
          end
        end
        
        self
      end
      
      def deep_delete(value)
        case value
        when Array
          value.each { |v| deep_delete(v) }
        when Hash
          value.each do |k, v|
            next unless self[k].is_a?(Hash)
            
            case v
            when Hash, Array
              self[k].deep_delete(v)
            when String, Symbol
              self[k].delete(v)
            end
          end
        when String, Symbol
          delete(value)
        end
      end
      
      def deep_merge(other_hash)
        self.merge(other_hash) do |key, oldval, newval|
          oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
          newval = newval.to_hash if newval.respond_to?(:to_hash)
          oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.deep_merge(newval) : newval
        end
      end

      # Returns a new hash with +self+ and +other_hash+ merged recursively.
      # Modifies the receiver in place.
      def deep_merge!(other_hash)
        replace(deep_merge(other_hash))
      end
      
      # assert_valid_keys was killing performance. Array.flatten was the culprit, so I rewrote this method, got a 35% performance increase
      def fast_assert_valid_keys(valid_keys)
        unknown_keys = keys - valid_keys
        raise(ArgumentError, "Unknown key(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
      end
    end
  end
end

Hash.send(:include, Searchlogic::CoreExt::Hash)