module Spree
  module TaxonRules
    class Sale < Spree::TaxonRule
      def apply(scope)
        case match_policy
        when 'is_equal_to' || 'contains'
          scope.on_sale(store.default_currency)
        when 'is_not_equal_to' || 'does_not_contain'
          scope.where.not(id: scope.on_sale(store.default_currency))
        else
          scope
        end
      end
    end
  end
end
