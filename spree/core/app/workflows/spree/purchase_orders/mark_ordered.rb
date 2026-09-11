module Spree
  module PurchaseOrders
    # The order has gone to the supplier. Freezes the lines and starts the
    # clock on the expected date; the goods are now "on order", which the
    # merchant can see but availability never counts.
    class MarkOrdered < Spree::Workflow
      include Spree::Receivables::IncomingCounter

      hooks :validate, :after_mark_ordered

      # @param purchase_order [Spree::PurchaseOrder]
      def perform(purchase_order:)
        super

        # One placement at a time per document: the draft check is what stops
        # an order being placed twice, and two callers reading it outside the
        # lock would both count the order's units as incoming — a surplus no
        # receipt could ever withdraw.
        purchase_order.with_lock do
          step :ensure_draft
          run_hooks :validate

          step :mark_ordered
          step :count_ordered_units
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

      # From this moment the goods are on their way as far as the Inventory
      # page is concerned — still never as far as availability is.
      def count_ordered_units
        count_incoming(purchase_order)
      end
    end
  end
end
