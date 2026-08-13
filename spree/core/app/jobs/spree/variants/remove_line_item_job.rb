module Spree
  module Variants
    class RemoveLineItemJob < Spree::BaseJob
      queue_as Spree.queues.variants

      def perform(line_item:)
        workflow = Spree.cart_upsert_items_workflow.new
        result = workflow.call(
          cart: line_item.owner,
          items: [{ variant_id: line_item.variant_id, quantity: 0 }]
        )

        # The cart-side contract turns a vetoed removal into a warning and
        # still succeeds, so the job has to look at the warnings to know the
        # line survived — otherwise a discontinued variant silently stays in
        # the cart with nothing to show for it.
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
