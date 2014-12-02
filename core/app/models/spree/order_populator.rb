module Spree
  class OrderPopulator
    attr_accessor :order
    attr_reader :errors

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

    def attempt_cart_add(variant_id, quantity, options)
      quantity = quantity.to_i
      # 2,147,483,647 is crazy.
      # See issue #2695.
      if quantity > 2_147_483_647
        errors.add(:base, Spree.t(:please_enter_reasonable_quantity, scope: :order_populator))
        return false
      end

      variant = order.line_items.detect { |line_item| line_item.variant_id.equal?(variant_id) }.try(:variant) ||
        Spree::Variant.find(variant_id)

      begin
        @order.contents.add(variant, quantity, options)
      rescue ActiveRecord::RecordInvalid => e
        errors.add(:base, e.record.errors.messages.values.join(" "))
      end
    end
  end
end
