module Searchlogic
  module CoreExt
    module Object
      # Get object's meta (ghost, eigenclass, singleton) class
      def metaclass
        class << self
          self
        end
      end

      # If class_eval is called on an object, add those methods to its metaclass
      def class_eval(*args, &block)
        metaclass.class_eval(*args, &block)
      end
    end
  end
end

Object.send(:include, Searchlogic::CoreExt::Object)