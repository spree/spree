module Spree
  module Orders
    # Removes a line item from a draft or placed order. The removal passes
    # the 'orders.upsert_items.validate' hook like every other item edit,
    # then the order is recalculated and its statuses re-derived, as
    # Spree::Orders::UpdateItem does for a quantity change.
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Order]
      # @param line_item [Spree::LineItem]
      # @param options [Hash] accepted for signature compatibility and ignored
      # @return [Spree::ServiceModule::Result] the removed line item, or a
      #   failure carrying why the removal was refused
      def call(order:, line_item:, options: {})
        result = nil

        # requires_new: a refused removal must roll back to here even when
        # the caller holds an open transaction (the API's order lock).
        ApplicationRecord.transaction(requires_new: true) do
          result = Spree.order_upsert_items_workflow.call(
            order: order,
            items: [{ variant_id: line_item.variant_id, quantity: 0 }]
          )
          raise ActiveRecord::Rollback if result.failure?

          result = Spree::Orders::Recalculate.call(order: order)
          raise ActiveRecord::Rollback if result.failure?

          order.update_statuses!
        end

        return failure(line_item, result.error&.value) if result.failure?

        success(line_item)
      end
    end
  end
end
