module Spree
  module StockTransfers
    # Ends a transfer whose missing units are not going to turn up.
    #
    # Eight of ten arrived and the box is not coming back for the other two.
    # The units already left the source when the transfer went in transit, so
    # nothing is written to any shelf: closing short keeps what the
    # destination counted in, records why the rest never arrived, and leaves
    # the outstanding count on each line as the record of the loss.
    class Close < Spree::Workflow
      hooks :validate, :after_close

      attr_reader :stock_transfer, :reason

      # @param stock_transfer [Spree::StockTransfer]
      # @param reason [String, nil] what happened to the balance
      def perform(stock_transfer:, reason: nil)
        super

        stock_transfer.with_lock do
          step :ensure_closable
          run_hooks :validate
          step :close_short
        end

        run_hooks :after_close
        stock_transfer.publish_event('stock_transfer.received')
        success(stock_transfer.reload)
      end

      private

      def ensure_closable
        return if stock_transfer.partially_received?

        failure(stock_transfer, Spree.t('stock_transfer.errors.not_partially_received'))
      end

      def close_short
        now = Time.current
        attributes = { status: 'received', received_at: now, closed_short_at: now, close_reason: reason.presence }

        failure(stock_transfer) unless stock_transfer.update(attributes)
      end
    end
  end
end
