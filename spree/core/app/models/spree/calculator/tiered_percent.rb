module Spree
  class Calculator::TieredPercent < Calculator
    include Spree::Calculator::Tiers

    preference :base_percent, :decimal, default: 0

    validates :preferred_base_percent, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    }

    def self.description
      I18n.t('spree.tiered_percent')
    end

    def compute(object)
      percent = tier_value_for(object.amount) || preferred_base_percent
      Spree::Money::Rounding.to_currency(object.amount * percent / 100, object.try(:currency))
    end

    private

    def validate_tier_values(values)
      errors.add(:preferred_tiers, :values_should_be_percent) unless values.all? { |value| value&.between?(0, 100) }
    end
  end
end
