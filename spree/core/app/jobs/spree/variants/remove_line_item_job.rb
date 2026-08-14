module Spree
  module Variants
    class RemoveLineItemJob < Spree::BaseJob
      queue_as Spree.queues.variants

      def perform(line_item:)
        owner = line_item.owner
        return if owner.nil?

        # Carts and draft orders have different contracts: the cart side turns
        # a vetoed removal into a warning and still succeeds, the order side
        # fails outright. Routing an order-owned line through the cart
        # workflow would apply cart semantics to an admin edit.
        cart_owned = owner.is_a?(Spree::Cart)
        workflow = (cart_owned ? Spree.cart_upsert_items_workflow : Spree.order_upsert_items_workflow).new

        result = workflow.call(
          **(cart_owned ? { cart: owner } : { order: owner }),
          items: [{ variant_id: line_item.variant_id, quantity: 0 }]
        )

        # A cart-side veto surfaces as a warning rather than a failed result,
        # so both have to be checked — otherwise a discontinued variant stays
        # in the cart with nothing to show for it.
        rejection = workflow.warnings.first
        return if result.success? && rejection.nil?

        Rails.error.report(
          RemovalRejected.new(rejection&.message || result.error.to_s),
          context: { line_item_id: line_item.id, variant_id: line_item.variant_id },
          source: 'spree.variants.remove_line_item',
          handled: true
        )
      end

      class RemovalRejected < StandardError; end
    end
  end
end
