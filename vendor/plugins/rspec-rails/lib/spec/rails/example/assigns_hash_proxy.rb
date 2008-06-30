module Spec
  module Rails
    module Example
      class AssignsHashProxy #:nodoc:
        def initialize(object)
          @object = object
        end

        def [](ivar)
          if assigns.include?(ivar.to_s)
            assigns[ivar.to_s]
          elsif assigns.include?(ivar)
            assigns[ivar]
          else
            nil
          end
        end

        def []=(ivar, val)
          @object.instance_variable_set "@#{ivar}", val
          assigns[ivar.to_s] = val
        end

        def delete(name)
          assigns.delete(name.to_s)
        end

        def each(&block)
          assigns.each &block
        end

        def has_key?(key)
          assigns.key?(key.to_s)
        end

        protected
        def assigns
          @object.assigns
        end
      end
    end
  end
end
