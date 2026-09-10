module Spree
  module StockTransfers
    # Records one delivery the destination warehouse counted in, as a stock
    # receipt.
    #
    # Partial receipt is the normal case, not an edge case: ten left, eight
    # arrived, two were crushed in transit. A delivery is booked as its own
    # receipt — what was accepted, what was refused and why — and adds to the
    # line's running total, so a second box tops it up rather than restating
    # it. Only accepted units reach the shelf.
    class Receive < Spree::Workflow
      include Spree::StockReceipts::Recording

      hooks :validate, :before_restock, :after_receive

      attr_reader :stock_transfer, :items, :received_at, :reference, :notes, :received_by,
                  :stock_receipt

      # @param stock_transfer [Spree::StockTransfer]
      # @param items [Array<Hash>, nil] `[{ item:, quantity_accepted:,
      #   quantity_rejected:, rejection_reason:, notes: }]` — this delivery's
      #   counts; nil books everything still outstanding, intact
      # @param received_at [Time, nil] defaults to now
      # @param reference [String, nil] the carrier's or packer's note
      # @param notes [String, nil]
      # @param received_by [Object, nil]
      def perform(stock_transfer:, items: nil, received_at: nil, reference: nil, notes: nil, received_by: nil)
        super
        record_delivery
      end

      private

      def receivable
        stock_transfer
      end

      def event_prefix
        'stock_transfer'
      end

      def error_scope
        'stock_transfer'
      end

      def ensure_receivable
        return if stock_transfer.in_flight?

        failure(stock_transfer, Spree.t('stock_transfer.errors.not_in_transit'))
      end

      def line_belongs?(line)
        line&.stock_transfer_id == stock_transfer.id
      end

      # Moving stock a merchant already owns is not a purchase.
      def unit_cost_for(_line)
        nil
      end
    end
  end
end
