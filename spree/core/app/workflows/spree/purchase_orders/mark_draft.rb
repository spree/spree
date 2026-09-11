module Spree
  module PurchaseOrders
    # Takes a placed order back to the drawing board.
    #
    # Only while nothing has arrived: once a delivery has been booked the
    # lines are a record of what was received against, and can no longer be
    # rewritten. The order's `ordered_at` is cleared, because it is no longer
    # ordered.
    class MarkDraft < Spree::Workflow
      include Spree::Receivables::IncomingCounter

      hooks :validate, :after_mark_draft

      attr_reader :purchase_order

      # @param purchase_order [Spree::PurchaseOrder]
      def perform(purchase_order:)
        super

        purchase_order.with_lock do
          step :ensure_returnable
          run_hooks :validate
          step :uncount_ordered_units
          step :return_to_draft
        end

        run_hooks :after_mark_draft
        purchase_order.publish_event('purchase_order.draft')
        success(purchase_order.reload)
      end

      private

      def ensure_returnable
        failure(purchase_order, Spree.t('purchase_order.errors.already_receiving')) if purchase_order.stock_receipts.exists?
        failure(purchase_order, Spree.t('purchase_order.errors.not_ordered_for_draft')) unless purchase_order.ordered?
      end

      # Nothing has been received, so this is every unit the order placed.
      def uncount_ordered_units
        uncount_incoming(purchase_order)
      end

      def return_to_draft
        failure(purchase_order) unless purchase_order.update(status: 'draft', ordered_at: nil)
      end
    end
  end
end
