module Spree
  class Calculator::TieredFlatRate < Calculator
    include Spree::Calculator::Tiers

    preference :base_amount, :money, default: 0
    preference :currency, :string, format: :currency, default: -> { Spree::Store.default.default_currency }

    def self.description
      I18n.t('spree.tiered_flat_rate')
    end

    def compute(object = nil)
      return 0 unless object&.currency.present?
      return 0 unless preferred_currency.casecmp(object.currency.upcase).zero?

      tier_value_for(object.amount) || preferred_base_amount
    end

    private

    def validate_tier_values(values)
      errors.add(:preferred_tiers, :values_should_be_number) unless values.all? { |value| value && value >= 0 }
    end
  end
end
