module Spree
  module PurchaseOrders
    # The order has gone to the supplier. Freezes the lines and starts the
    # clock on the expected date; the goods are now "on order", which the
    # merchant can see but availability never counts.
    class MarkOrdered < Spree::Workflow
      hooks :validate, :after_mark_ordered

      # @param purchase_order [Spree::PurchaseOrder]
      def perform(purchase_order:)
        super

        step :ensure_draft
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_ordered
        end

        run_hooks :after_mark_ordered
        purchase_order.publish_event('purchase_order.ordered')
        success(purchase_order.reload)
      end

      private

      def ensure_draft
        failure(purchase_order, Spree.t('purchase_order.errors.not_draft')) unless purchase_order.draft?
        failure(purchase_order, Spree.t('purchase_order.errors.must_have_variant')) if purchase_order.items.empty?
      end

      def mark_ordered
        failure(purchase_order) unless purchase_order.update(status: 'ordered', ordered_at: Time.current)
      end
    end
  end
end
