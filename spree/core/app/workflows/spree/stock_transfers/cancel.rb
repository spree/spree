module Spree
  module StockTransfers
    # Calls the trip off.
    #
    # Cancelling a draft or a packed transfer costs nothing — no stock has
    # moved. Cancelling one already in transit is a decision the merchant has
    # to make, because the units are physically gone from the source: either
    # they come back (`restock`, as if the box never left) or they are written
    # off (`write_off`, shrinkage). There is no silent reversal, and no
    # default: guessing would either invent stock or destroy it.
    class Cancel < Spree::Workflow
      hooks :validate, :after_cancel

      # How in-flight units are accounted for.
      IN_TRANSIT_RESOLUTIONS = %w[restock write_off].freeze

      # Recorded on every line the merchant wrote off without saying why.
      DEFAULT_WRITE_OFF_REASON = 'lost_in_transit'.freeze

      # @param stock_transfer [Spree::StockTransfer]
      # @param on_in_transit [String, nil] `'restock'` or `'write_off'`;
      #   required once the units have left the source
      # @param reason [String, nil] audit text for the write-off
      # @param canceler [Object, nil]
      def perform(stock_transfer:, on_in_transit: nil, reason: nil, canceler: nil)
        super

        # One cancellation at a time per document, and no receive alongside it.
        # Each line's outstanding quantity is what is still in flight, so a
        # receive committing between reading it and restocking the source
        # credits the same units twice — once onto the destination shelf, once
        # back onto the source. Locked document-then-level, as `Receive` does.
        stock_transfer.with_lock do
          step :ensure_cancelable
          run_hooks :validate

          step :resolve_in_flight_units
          step :mark_canceled
        end

        run_hooks :after_cancel
        stock_transfer.publish_event('stock_transfer.canceled')
        success(stock_transfer.reload)
      end

      private

      def ensure_cancelable
        failure(stock_transfer, Spree.t('stock_transfer.errors.already_closed')) if stock_transfer.closed?
        return unless stock_transfer.in_flight?
        return if IN_TRANSIT_RESOLUTIONS.include?(on_in_transit)

        failure(stock_transfer, Spree.t('stock_transfer.errors.in_transit_resolution_required'))
      end

      # Only the units still in flight are resolved: anything the destination
      # already counted in is on its shelf and stays there.
      def resolve_in_flight_units
        return unless stock_transfer.in_flight?

        # Read the running totals under the lock: an association loaded before
        # it holds the quantities as they were before any receive that has
        # since committed, and those are what `outstanding` subtracts from.
        return write_off if on_in_transit == 'write_off'

        stock_transfer.items.reload.each do |item|
          next unless item.outstanding.positive?

          restock(item)
        end
      end

      # Back onto the source's shelf, as if the box had never left. Written as
      # a `received` movement carrying this transfer, so the departure and its
      # reversal reconcile against each other in the ledger.
      def restock(item)
        stock_transfer.source_location.restock(item.variant, item.outstanding, stock_transfer)
      end

      # Nothing to write to the shelf: the units left the source when the
      # transfer was marked in transit and never arrived anywhere, so the loss
      # is already in the ledger. What is missing is why, and that is recorded
      # as the reason the transfer closed — the same place a short close puts
      # it.
      def write_off
        @close_reason = reason.presence || DEFAULT_WRITE_OFF_REASON
      end

      def mark_canceled
        failure(stock_transfer) unless stock_transfer.update(status: 'canceled', close_reason: @close_reason)
      end
    end
  end
end
