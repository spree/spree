module Spree
  class Calculator::FlatPercentItemTotal < Calculator
    preference :flat_percent, :decimal, default: 0

    def self.description
      I18n.t('spree.flat_percent')
    end

    def compute(object)
      computed_amount = Spree::Money::Rounding.to_currency(object.amount * preferred_flat_percent / 100, object.try(:currency))

      # We don't want to cause the promotion adjustments to push the order into a negative total.
      if computed_amount > object.amount
        object.amount
      else
        computed_amount
      end
    end
  end
end
