module Spree
  module CollectionRules
    # Products whose name, in the store's default locale, matches the value.
    # Case-insensitive.
    class Title < Spree::CollectionRule
      def self.match_policies
        %w[is_equal_to is_not_equal_to contains does_not_contain starts_with ends_with]
      end

      def apply(scope)
        term = Spree::Product.sanitize_sql_like(value.to_s)
        pattern = case match_policy
                  when 'contains', 'does_not_contain' then "%#{term}%"
                  when 'starts_with' then "#{term}%"
                  when 'ends_with' then "%#{term}"
                  else term
                  end

        match(scope, Spree::Product.where(Spree::Product.arel_table[:name].matches(pattern, '\\')))
      end
    end
  end
end
