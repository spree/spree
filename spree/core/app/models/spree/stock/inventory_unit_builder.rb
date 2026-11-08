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
        line_items = @order.line_items.to_a
        # Allocation asks each variant how it ships, so the variants and their
        # delivery profiles are read once for the whole cart.
        ActiveRecord::Associations::Preloader.new(
          records: line_items, associations: { variant: [:delivery_profile, { product: :delivery_profile }] }
        ).call

        line_items.map do |line_item|
          # They go through multiple splits, avoid loading the
          # association to order until needed.
          unit = Spree::FulfillmentItem.new(
            pending: true,
            line_item_id: line_item.id,
            variant_id: line_item.variant_id,
            quantity: line_item.quantity,
            order_id: @order.is_a?(Spree::Order) ? @order.id : nil
          )
          # Set as targets rather than assigned, so the proposed unit is not
          # added to the line item's own fulfillment_items.
          unit.association(:line_item).target = line_item
          unit.association(:variant).target = line_item.variant
          unit
        end
      end
    end
  end
end
