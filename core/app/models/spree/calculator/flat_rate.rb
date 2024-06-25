require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatRate < Calculator
    preference :amount, :decimal, default: 0
    preference :currency, :string, default: -> { Spree::Store.default.default_currency }
    preference :apply_only_on_full_priced_items, :boolean, default: false

    def self.description
      Spree.t(:flat_rate_per_order)
    end

    def compute(object = nil)
      return 0 if preferred_apply_only_on_full_priced_items && object&.variant&.compare_at_amount_in(object.currency).present?

      if object && preferred_currency.casecmp(object.currency.upcase).zero?
        preferred_amount
      else
        0
      end
    end
  end
end
