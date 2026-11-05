module Spree
  module CollectionRules
    # Products whose name, in the store's default locale, matches the value.
    # Case-insensitive.
    class Title < Spree::CollectionRule
      def self.match_policies
        %w[is_equal_to is_not_equal_to contains does_not_contain starts_with ends_with]
      end

      def apply(scope)
        match(scope, Spree::Product.where(Spree::Product.arel_table[:name].matches(like_pattern, '\\')))
      end
    end
  end
end
