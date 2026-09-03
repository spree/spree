module Spree
  module Stock
    class InventoryUnitBuilder
      def initialize(order)
        @order = order
      end

      def units
        # Same rule as Spree::Fulfillment#set_up_inventory: the item's order_id
        # is a completion-time denormalization, so during checkout it stays nil
        # rather than pointing at whatever order happens to share the cart's
        # id — a stranger's order whose currency and ship address would then
        # stand in for the customer's.
        @order.line_items.map do |line_item|
          # They go through multiple splits, avoid loading the
          # association to order until needed.
          Spree::InventoryUnit.new(
            pending: true,
            line_item_id: line_item.id,
            variant_id: line_item.variant_id,
            quantity: line_item.quantity,
            order_id: @order.is_a?(Spree::Order) ? @order.id : nil
          )
        end
      end
    end
  end
end
