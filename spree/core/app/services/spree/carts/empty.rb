module Spree
  module Carts
    class Empty
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil)
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::Empty with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        rewrite_input!(remove: [:order], cart: cart)
        run :check_if_can_be_empty
        run :empty_order
      end

      private

      def check_if_can_be_empty(cart:)
        return failure(Spree.t(:cannot_empty)) if cart.nil? || cart.completed?

        success(cart: cart)
      end

      def empty_order(cart:)
        ActiveRecord::Base.transaction do
          cart.line_items.destroy_all
          cart.update_columns(total_quantity: 0, updated_at: Time.current)
          cart.tax_lines.destroy_all
          cart.discounts.destroy_all
          cart.fees.destroy_all
          cart.fulfillments.destroy_all
          cart.order_promotions.destroy_all
          cart.recalculate_totals!

          Spree::StockReservations::Release.call(cart: cart)

          success(cart)
        end
      end
    end
  end
end
