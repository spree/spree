module Spree
  module PurchaseOrders
    # Books in one delivery from the supplier, as a stock receipt.
    #
    # This is the moment purchased goods first exist as far as availability is
    # concerned: nothing before it touched `count_on_hand`, because a merchant
    # who has ordered stock does not have it. Suppliers under-ship and
    # back-order routinely, so a delivery is booked as its own receipt and adds
    # to the line's running total; over-shipments are booked as they come and
    # close the order as `over_received`.
    #
    # Each `received` movement carries the line's `unit_cost`, which is what a
    # rolling average cost is computed from — including across two deliveries
    # agreed at different prices.
    class Receive < Spree::Workflow
      include Spree::StockReceipts::Recording

      hooks :validate, :before_restock, :after_receive

      attr_reader :purchase_order, :items, :received_at, :reference, :notes, :received_by,
                  :stock_receipt

      # @param purchase_order [Spree::PurchaseOrder]
      # @param items [Array<Hash>, nil] `[{ item:, quantity_accepted:,
      #   quantity_rejected:, rejection_reason:, notes: }]` — this delivery's
      #   counts; nil books everything still outstanding, intact
      # @param received_at [Time, nil] defaults to now
      # @param reference [String, nil] the supplier's delivery note
      # @param notes [String, nil]
      # @param received_by [Object, nil]
      def perform(purchase_order:, items: nil, received_at: nil, reference: nil, notes: nil, received_by: nil)
        super
        record_delivery
      end

      private

      def receivable
        purchase_order
      end

      def event_prefix
        'purchase_order'
      end

      def error_scope
        'purchase_order'
      end

      def ensure_receivable
        return if purchase_order.ordered? || purchase_order.partially_received?

        failure(purchase_order, Spree.t('purchase_order.errors.not_ordered'))
      end

      def line_belongs?(line)
        line&.purchase_order_id == purchase_order.id
      end

      def unit_cost_for(line)
        line.unit_cost
      end
    end
  end
end
