module Spree
  module CollectionRules
    # Products with a variant that can be sold now: in stock, backorderable
    # or not tracked. `is_not_equal_to` matches the products that can't.
    class InStock < Spree::CollectionRule
      def self.match_policies
        %w[is_equal_to is_not_equal_to]
      end

      def self.value_required?
        false
      end

      def apply(scope)
        match(scope, Spree::Product.in_stock_or_backorderable)
      end
    end
  end
end
