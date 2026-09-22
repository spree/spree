module Spree
  module StockTransfers
    # The box is packed. Freezes the lines so the warehouse and the merchant
    # are looking at the same list, without yet taking anything off the shelf.
    class MarkReady < Spree::Workflow
      hooks :validate, :after_mark_ready

      # @param stock_transfer [Spree::StockTransfer]
      def perform(stock_transfer:)
        super

        step :ensure_draft
        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_ready
        end

        run_hooks :after_mark_ready
        stock_transfer.publish_event('stock_transfer.ready_to_ship')
        success(stock_transfer.reload)
      end

      private

      def ensure_draft
        failure(stock_transfer, Spree.t('stock_transfer.errors.not_draft')) unless stock_transfer.draft?
        failure(stock_transfer, Spree.t('stock_transfer.errors.must_have_variant')) if stock_transfer.items.empty?
      end

      def mark_ready
        failure(stock_transfer) unless stock_transfer.update(status: 'ready_to_ship')
      end
    end
  end
end
