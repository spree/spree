module Spree
  module PurchaseOrders
    # Ends an order the supplier will not complete.
    #
    # Eight of ten arrived and the last two are not coming. Cancelling would
    # deny the eight, and waiting leaves the order open forever; closing short
    # keeps what was received, records that the rest never came and why, and
    # lets the outstanding count stand on each line as the record of the gap.
    # No stock moves — the units were never here.
    class Close < Spree::Workflow
      hooks :validate, :after_close

      attr_reader :purchase_order, :reason

      # @param purchase_order [Spree::PurchaseOrder]
      # @param reason [String, nil] why the balance is not expected
      def perform(purchase_order:, reason: nil)
        super

        purchase_order.with_lock do
          step :ensure_closable
          run_hooks :validate
          step :close_short
        end

        run_hooks :after_close
        purchase_order.publish_event('purchase_order.received')
        success(purchase_order.reload)
      end

      private

      def ensure_closable
        return if purchase_order.partially_received?

        failure(purchase_order, Spree.t('purchase_order.errors.not_partially_received'))
      end

      def close_short
        now = Time.current
        attributes = { status: 'received', received_at: now, closed_short_at: now, close_reason: reason.presence }

        failure(purchase_order) unless purchase_order.update(attributes)
      end
    end
  end
end
