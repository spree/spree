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
        result = nil
        # A savepoint: a caller's transaction (the API's order lock) joins the
        # workflow's own, so a late rejection would otherwise commit the removal.
        ActiveRecord::Base.transaction(requires_new: true) do
          result = Spree.order_upsert_items_workflow.call(
            order: order,
            items: [{ variant_id: line_item.variant_id, quantity: 0 }]
          )
          raise ActiveRecord::Rollback if result.failure?
        end
        return failure(line_item, result.error) if result.failure?

        # The order workflow leaves totals to its caller.
        Spree::Orders::Recalculate.call(order: order)
        order.update_statuses!

        success(line_item)
      end
    end
  end
end
