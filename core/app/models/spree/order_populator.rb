module Spree
  class OrderPopulator
    QUANTITY_RANGE = (1..2**31 - 1).freeze

    attr_accessor :order, :currency
    attr_reader :errors

    def initialize(order, currency)
      @order    = order
      @currency = currency
      @errors   = ActiveModel::Errors.new(nil)
    end

    def populate(variant_id, quantity)
      line_item = order.line_items.detect do |line_item|
        line_item.variant_id.equal?(variant_id)
      end

      variant = line_item.try(:variant) || Variant.find_by_id(variant_id)

      validate_variant(variant)
      validate_quantity(quantity)

      valid? && attempt_cart_add(variant, quantity)
    end

    def valid?
      errors.empty?
    end

    private

    def validate_variant(variant)
      unless variant
        errors.add(:base, Spree.t(:invalid_variant, scope: :order_populator))
      end
    end

    def validate_quantity(quantity)
      if quantity.zero?
        errors.add(:base, Spree.t(:please_enter_positive_quantity, scope: :order_populator))
      elsif !QUANTITY_RANGE.cover?(quantity)
        errors.add(:base, Spree.t(:please_enter_reasonable_quantity, scope: :order_populator))
      end
    end

    def attempt_cart_add(variant, quantity)
      line_item = @order.contents.add(variant, quantity, currency)
      return true if line_item.valid?
      errors.add(:base, line_item.errors.to_a.join(' '))
      false
    end
  end
end
