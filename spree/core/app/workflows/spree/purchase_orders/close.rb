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
      include Spree::Receivables::ClosingShort

      hooks :validate, :after_close

      attr_reader :purchase_order, :reason

      # @param purchase_order [Spree::PurchaseOrder]
      # @param reason [String, nil] why the balance is not expected
      def perform(purchase_order:, reason: nil)
        super
        close
      end

      private

      def receivable = purchase_order
    end
  end
end
