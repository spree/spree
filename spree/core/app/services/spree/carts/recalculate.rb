module Spree
  module Carts
    class Recalculate
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil, line_item: nil, line_item_created: false, options: {})
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::Recalculate with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        order_updater = cart.updater

        cart.remove_gift_card if cart.gift_card.present?
        cart.payments.store_credits.checkout.destroy_all if cart.payments.store_credits.checkout.any?
        # Totals must be current before the proposal rebuild — delivery rate
        # calculators (e.g. price sack) read them.
        order_updater.update_item_count
        order_updater.update_totals
        order_updater.persist_totals

        cart.ensure_updated_fulfillments

        ::Spree::PromotionHandler::Cart.new(cart, line_item).activate
        # Typed rows (discounts + tax) are rebuilt by the order-level
        # recalculation inside the updater.
        order_updater.update
        success(line_item)
      end
    end
  end
end
