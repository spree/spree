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
          InventoryUnit.new(
            pending:    true,
            line_item:  line_item,
            variant:    line_item.variant,
            quantity:   line_item.quantity,
            order_id:   @order.id
          )
        end
      end
    end
  end
end
