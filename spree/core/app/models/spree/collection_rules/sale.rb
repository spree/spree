# frozen_string_literal: true

module Spree
  module CollectionRules
    # Products discounted below their compare-at price in the rule's currency
    # (the store's default when blank).
    class Sale < Spree::CollectionRule
      def apply(scope)
        case match_policy
        when 'is_equal_to', 'contains'
          scope.on_sale(rule_currency)
        when 'is_not_equal_to', 'does_not_contain'
          scope.where.not(id: scope.on_sale(rule_currency))
        else
          scope
        end
      end
    end
  end
end
