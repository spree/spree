module Spree
  class Calculator::FlatRate < Calculator
    preference :amount, :money, default: 0
    preference :currency, :string, format: :currency, default: -> { Spree::Store.default.default_currency }
    preference :apply_only_on_full_priced_items, :boolean, default: false

    def self.description
      I18n.t('spree.flat_rate_per_order')
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
