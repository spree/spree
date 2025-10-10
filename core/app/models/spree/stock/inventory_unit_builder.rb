module Spree
  module Stock
    class InventoryUnitBuilder
      def initialize(order)
        @order = order
      end

      def units
        @order.line_items.map do |line_item|
          # They go through multiple splits, avoid loading the
          # association to order until needed.
          Spree::InventoryUnit.new(
            pending: true,
            line_item_id: line_item.id,
            variant_id: line_item.variant_id,
            quantity: line_item.quantity,
            order_id: @order.id
          )
        end
      end
    end
  end
end
