module Spree
  module CollectionRules
    # Products whose name, in the store's default locale, matches the value.
    # Case-insensitive.
    class Title < Spree::CollectionRule
      def self.match_policies
        %w[is_equal_to is_not_equal_to contains does_not_contain starts_with ends_with]
      end

      def apply(scope)
        pattern = like_pattern
        matching = Mobility.with_locale(store.default_locale) { Spree::Product.i18n { name.matches(pattern, '\\') }.pluck(Spree::Product.arel_table[:id]) }
        match(scope, Spree::Product.where(id: matching))
      end
    end
  end
end
