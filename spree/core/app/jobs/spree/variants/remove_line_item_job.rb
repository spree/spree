module Spree
  module Variants
    class RemoveLineItemJob < Spree::BaseJob
      queue_as Spree.queues.variants

      def perform(line_item:)
        Spree.cart_upsert_items_workflow.call(
          cart: line_item.owner,
          items: [{ variant_id: line_item.variant_id, quantity: 0 }]
        )
      end
    end
  end
end
