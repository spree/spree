module Spree
  module StockTransfers
    # Records what the destination warehouse actually counted in.
    #
    # Partial receipt is the normal case, not an edge case: ten left, eight
    # arrived, two were crushed in transit. Quantities therefore come from the
    # caller — `quantity_received` is the running total for the line, so a
    # second receive of the same box tops it up rather than starting over — and
    # only the difference from last time is written to the shelf.
    class Receive < Spree::Workflow
      hooks :validate, :before_restock, :after_receive

      # @param stock_transfer [Spree::StockTransfer]
      # @param items [Array<Hash>, nil] `[{ item:, quantity_received:,
      #   discrepancy_reason: }]`; nil receives every line in full
      # @param received_by [Object, nil]
      def perform(stock_transfer:, items: nil, received_by: nil)
        super

        step :ensure_receivable
        step :normalize_items
        run_hooks :validate

        ApplicationRecord.transaction do
          step :record_receipt
          run_hooks :before_restock
          step :restock_deltas
          step :settle_status
        end

        run_hooks :after_receive
        stock_transfer.publish_event("stock_transfer.#{stock_transfer.status}")
        success(stock_transfer.reload)
      end

      private

      def ensure_receivable
        return if stock_transfer.in_flight?

        failure(stock_transfer, Spree.t('stock_transfer.errors.not_in_transit'))
      end

      def normalize_items
        @normalized_items =
          if items.nil?
            stock_transfer.items.map do |line|
              { item: line, quantity_received: line.quantity_shipped,
                delta: line.outstanding }
            end
          else
            Array(items).map { |item| normalize_item(item) }
          end

        return if @normalized_items.any? { |item| item[:delta].positive? }

        failure(stock_transfer, Spree.t('stock_transfer.errors.no_items_received'))
      end

      # The running total may only go up: un-receiving units already put on
      # the shelf is a correction, which is what a manual adjustment is for.
      def normalize_item(item)
        line = item[:item]
        failure(stock_transfer, Spree.t('stock_transfer.errors.item_not_on_transfer')) unless
          line&.stock_transfer_id == stock_transfer.id

        quantity = item[:quantity_received].to_i
        if quantity.negative? || quantity > line.quantity_shipped || quantity < line.quantity_received
          failure(stock_transfer, Spree.t('stock_transfer.errors.invalid_received_quantity',
                                          variant: line.variant_name, shipped: line.quantity_shipped))
        end

        normalized = {
          item: line,
          quantity_received: quantity,
          delta: quantity - line.quantity_received.to_i
        }
        # Carried through only when the caller named one, so a top-up receive
        # that says nothing about the discrepancy leaves the recorded reason
        # alone rather than erasing it.
        normalized[:discrepancy_reason] = item[:discrepancy_reason] if item.key?(:discrepancy_reason)
        normalized
      end

      def record_receipt
        @normalized_items.each do |item|
          attributes = { quantity_received: item[:quantity_received] }
          attributes[:discrepancy_reason] = item[:discrepancy_reason] if item.key?(:discrepancy_reason)

          item[:item].update!(attributes)
        end
      end

      # Only the difference lands on the shelf. A second receive that tops a
      # line up from eight to ten adds two, not ten.
      def restock_deltas
        destination = stock_transfer.destination_location

        @normalized_items.each do |item|
          next unless item[:delta].positive?

          destination.restock(item[:item].variant, item[:delta], stock_transfer)
        end
      end

      # `received` once every line is complete, `partially_received` while any
      # is still owed — and `received_at` is stamped only when the trip is
      # actually over.
      def settle_status
        # The caller's lines are freshly-loaded instances, not the ones the
        # association is holding, so the totals have to be re-read before they
        # can decide the status.
        stock_transfer.items.reset
        status = stock_transfer.status_after_receive
        attributes = { status: status }
        attributes[:received_at] = Time.current if status == 'received'

        failure(stock_transfer) unless stock_transfer.update(attributes)
      end
    end
  end
end
