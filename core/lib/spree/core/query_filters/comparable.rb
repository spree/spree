module Spree
  module Core
    module QueryFilters
      class Comparable
        def initialize(attribute:)
          @attribute = attribute
        end

        def call(scope:, filter:)
          scope = gt(scope, filter[:gt])
          scope = gteq(scope, filter[:gteq])
          scope = lt(scope, filter[:lt])
          lteq(scope, filter[:lteq])
        end

        private

        attr_reader :attribute

        def gt(scope, value)
          return scope unless value

          scope.where(attribute.gt(value))
        end

        def gteq(scope, value)
          return scope unless value

          scope.where(attribute.gteq(value))
        end

        def lt(scope, value)
          return scope unless value

          scope.where(attribute.lt(value))
        end

        def lteq(scope, value)
          return scope unless value

          scope.where(attribute.lteq(value))
        end
      end
    end
  end
end
