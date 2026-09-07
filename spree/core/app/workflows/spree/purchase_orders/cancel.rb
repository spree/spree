module Spree
  module PurchaseOrders
    # Calls the order off.
    #
    # Nothing to unwind: a purchase order never moved stock until units were
    # received, and units already received stay on the shelf — the merchant has
    # them. Cancelling closes what is still outstanding, which is a message to
    # accounts payable rather than a stock correction.
    class Cancel < Spree::Workflow
      hooks :validate, :after_cancel

      # @param purchase_order [Spree::PurchaseOrder]
      # @param reason [String, nil] why it was called off; appended to the
      #   order's notes, which is what the merchant reads afterwards
      # @param canceler [Object, nil]
      def perform(purchase_order:, reason: nil, canceler: nil)
        super

        step :ensure_cancelable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_canceled
        end

        run_hooks :after_cancel
        purchase_order.publish_event('purchase_order.canceled')
        success(purchase_order.reload)
      end

      private

      def ensure_cancelable
        return unless purchase_order.closed?

        failure(purchase_order, Spree.t('purchase_order.errors.already_closed'))
      end

      def mark_canceled
        notes = [purchase_order.notes, reason].compact_blank.join("\n")

        failure(purchase_order) unless purchase_order.update(status: 'canceled', notes: notes)
      end
    end
  end
end
