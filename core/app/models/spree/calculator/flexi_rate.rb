require_dependency 'spree/calculator'

module Spree
  class Calculator::FlexiRate < Calculator
    preference :first_item,      :decimal, default: 0.0
    preference :additional_item, :decimal, default: 0.0
    preference :max_items,       :integer, default: 0
    preference :currency,        :string,  default: -> { Spree::Store.default.default_currency }
    preference :apply_only_on_full_priced_items, :boolean, default: false

    def self.description
      Spree.t(:flexible_rate)
    end

    def self.available?(_object)
      true
    end

    def compute(object)
      return 0 if preferred_apply_only_on_full_priced_items && object.variant.compare_at_amount_in(object.currency).present?

      compute_from_quantity(object.quantity)
    end

    def compute_from_quantity(quantity)
      count = [quantity, preferred_max_items].reject(&:zero?).min

      return BigDecimal(0) if count.zero?

      preferred_first_item + (count - 1) * preferred_additional_item
    end
  end
end
