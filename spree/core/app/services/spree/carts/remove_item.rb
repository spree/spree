module Spree
  module Carts
    class RemoveItem
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil, variant: nil, quantity: nil, options: nil)
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::RemoveItem with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        options ||= {}
        quantity ||= 1

        ActiveRecord::Base.transaction do
          line_item = remove_from_line_item(cart: cart, variant: variant, quantity: quantity, options: options)
          Spree.cart_recalculate_workflow.call(line_item: line_item,
                                              cart: cart,
                                              options: options)
          success(line_item)
        end
      end

      private

      def remove_from_line_item(cart:, variant:, quantity:, options:)
        line_item = Spree.line_item_by_variant_finder.new.execute(cart: cart, variant: variant, options: options)

        raise ActiveRecord::RecordNotFound if line_item.nil?

        line_item.quantity -= quantity

        if line_item.quantity.zero?
          cart.line_items.destroy(line_item)
        else
          line_item.save!
        end

        line_item
      end
    end
  end
end
