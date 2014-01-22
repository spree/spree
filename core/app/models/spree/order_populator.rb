module Spree
  class OrderPopulator
    attr_accessor :order, :currency
    attr_reader :errors

    def initialize(order, currency)
      @order = order
      @currency = currency
      @errors = ActiveModel::Errors.new(self)
    end

    
    def populate(variant_id, quantity)
      attempt_cart_add(variant_id, quantity)
      valid?
    end

    def valid?
      errors.empty?
    end

    private

    def attempt_cart_add(variant_id, quantity)
      quantity = quantity.to_i
      # 2,147,483,647 is crazy.
      # See issue #2695.
      if quantity > 2_147_483_647
        errors.add(:base, Spree.t(:please_enter_reasonable_quantity, :scope => :order_populator))
        return false
      end

      variant = Spree::Variant.find(variant_id)
      if quantity > 0
        line_item = @order.contents.add(variant, quantity, currency)
        unless line_item.valid?
          errors.add(:base, line_item.errors.messages.values.join(" "))
          return false
        end
      end
    end
  end
end
