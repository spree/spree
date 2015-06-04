module Spree
  class OrderPopulator
    QUANTITY_RANGE  = (1..2**31 - 1).freeze
    ERROR_SEPARATOR = ', '.freeze

    attr_reader :order, :errors

    def initialize(order)
      @order = order
      @errors = ActiveModel::Errors.new(self)
    end

    def populate(variant_id, quantity, options = {})
      ActiveSupport::Deprecation.warn "OrderPopulator is deprecated and will be removed from Spree 3, use OrderContents with order.contents.add instead.", caller
      # protect against passing a nil hash being passed in
      # due to an empty params[:options]
      attempt_cart_add(variant_id, quantity, options || {})
      valid?
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

    def attempt_cart_add(variant_id, quantity, options)
      variant = order.line_items.detect { |line_item| line_item.variant_id.equal?(variant_id) }.try(:variant) ||
        Spree::Variant.find(variant_id)

      validate_variant(variant)
      validate_quantity(quantity)

      return unless valid?

      begin
        line_item = @order.contents.add(variant, quantity, options)
        return if line_item.valid?
        errors.add(:base, line_item.errors.values.join(ERROR_SEPARATOR))
      rescue ActiveRecord::RecordInvalid => e
        errors.add(:base, e.record.errors.messages.values.join(" "))
      end
    end
  end
end
