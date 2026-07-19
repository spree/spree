# frozen_string_literal: true

module Spree
  module CollectionRules
    class Tag < Spree::CollectionRule
      def apply(scope)
        if match_policy == 'is_equal_to'
          scope.tagged_with(value)
        elsif match_policy == 'is_not_equal_to'
          scope.tagged_with(value, exclude: true)
        elsif match_policy == 'contains'
          scope.tagged_with(value, any: true)
        elsif match_policy == 'does_not_contain'
          scope.tagged_with(value, any: true, exclude: true)
        else
          scope
        end
      end
    end
  end
end
