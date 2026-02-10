module Spree
  module Core
    module QueryFilters
      class Text
        def initialize(attribute:)
          @attribute = attribute
        end

        def call(scope:, filter:)
          scope = eq(scope, filter[:eq])
          contains(scope, filter[:contains])
        end

        private

        attr_reader :attribute

        def eq(scope, value)
          return scope unless value

          scope.where(attribute.eq(value))
        end

        def contains(scope, value)
          return scope unless value

          scope.where(attribute.matches("%#{value}%"))
        end
      end
    end
  end
end
