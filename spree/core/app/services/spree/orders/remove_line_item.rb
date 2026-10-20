module Spree
  module Orders
    # Draft-order twin of the cart service. Removing an item is an upsert with
    # quantity zero, so the removal passes the same 'orders.upsert_items.validate'
    # hook every other draft-order item edit does.
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Order]
      # @param line_item [Spree::LineItem]
      # @param options [Hash] accepted for signature compatibility and ignored
      # @return [Spree::ServiceModule::Result] value is the removed line item
      def call(order:, line_item:, options: {})
        result = Spree.order_upsert_items_workflow.call(
          order: order,
          items: [{ variant_id: line_item.variant_id, quantity: 0 }]
        )

        result.success? ? success(line_item) : failure(line_item, result.error)
      end
    end
  end
end
