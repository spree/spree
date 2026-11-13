module Spree
  module CollectionRules
    # Products with a variant priced above or below an amount, in the rule's
    # currency (the store's default when blank). Base prices only: a price
    # list is what one audience pays, not the shelf price.
    class Price < Spree::CollectionRule
      def self.uses_currency?
        true
      end

      validate :value_must_be_an_amount, if: -> { value.present? }

      def self.match_policies
        %w[greater_than less_than]
      end

      def apply(scope)
        amount_column = Spree::Price.arel_table[:amount]
        condition = match_policy == 'greater_than' ? amount_column.gt(amount) : amount_column.lt(amount)
        prices = Spree::Price.where(currency: rule_currency, price_list_id: nil).where(condition)

        scope.where(id: Spree::Variant.where(id: prices.select(:variant_id)).select(:product_id))
      end

      # @return [BigDecimal, nil]
      def amount
        Spree::Money::Rounding.parse_canonical(value, rule_currency)
      rescue Spree::Money::InvalidFormat
        nil
      end

      private

      def value_must_be_an_amount
        errors.add(:value, :not_a_number) if amount.nil?
      end
    end
  end
end
