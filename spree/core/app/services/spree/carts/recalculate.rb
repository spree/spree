module Spree
  module Carts
    class Recalculate
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, line_item_created: false, options: {})
        order_updater = order.updater

        order.remove_gift_card if order.gift_card.present?
        order.payments.store_credits.checkout.destroy_all if order.payments.store_credits.checkout.any?
        # Totals must be current before the proposal rebuild — delivery rate
        # calculators (e.g. price sack) read them.
        order_updater.update_item_count
        order_updater.update_totals
        order_updater.persist_totals

        order.ensure_updated_shipments

        ::Spree::PromotionHandler::Cart.new(order, line_item).activate
        # Typed rows (discounts + tax) are rebuilt by the order-level
        # recalculation inside the updater.
        order_updater.update
        success(line_item)
      end
    end
  end
end
