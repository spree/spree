module Spree
  module StockTransfers
    # Unfreezes a packed transfer so its lines can be changed again.
    #
    # Only from `ready_to_ship`: nothing has left the source yet, so there is
    # nothing to undo. Once the van has gone, what is in the box is a matter
    # of record.
    class MarkDraft < Spree::Workflow
      hooks :validate, :after_mark_draft

      attr_reader :stock_transfer

      # @param stock_transfer [Spree::StockTransfer]
      def perform(stock_transfer:)
        super

        stock_transfer.with_lock do
          step :ensure_returnable
          run_hooks :validate
          step :return_to_draft
        end

        run_hooks :after_mark_draft
        stock_transfer.publish_event('stock_transfer.draft')
        success(stock_transfer.reload)
      end

      private

      def ensure_returnable
        return if stock_transfer.ready_to_ship?

        failure(stock_transfer, Spree.t('stock_transfer.errors.not_ready_to_ship'))
      end

      def return_to_draft
        failure(stock_transfer) unless stock_transfer.update(status: 'draft')
      end
    end
  end
end
