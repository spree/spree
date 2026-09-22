module Spree
  module StockTransfers
    # Edits a draft transfer. Once the box is marked ready what is in it is a
    # matter of record, so this refuses anything past `draft` rather than
    # quietly rewriting a document the warehouse is already acting on.
    class Update < Spree::Workflow
      hooks :validate, :after_update

      # @param stock_transfer [Spree::StockTransfer]
      # @param attributes [Hash] editable columns — reference, notes, the two
      #   locations, metadata
      # @param items [Array<Hash>, nil] `[{ variant:, quantity_shipped: }]`
      #   replacing the current lines; nil leaves them alone
      def perform(stock_transfer:, attributes: {}, items: nil)
        super

        step :ensure_editable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :apply_changes
          step :save_transfer
        end

        run_hooks :after_update
        success(stock_transfer.reload)
      end

      private

      def ensure_editable
        return if stock_transfer.editable?

        failure(stock_transfer, Spree.t('stock_transfer.errors.not_editable'))
      end

      # A whole-list replacement rather than a per-line diff: a draft's lines
      # are what the merchant is still deciding, and sending the list they
      # want is simpler for a client than working out which rows to delete.
      def apply_changes
        stock_transfer.assign_attributes(attributes) if attributes.present?
        return if items.nil?

        stock_transfer.items.destroy_all
        Array(items).each do |item|
          stock_transfer.items.build(variant: item[:variant], quantity_shipped: item[:quantity_shipped])
        end
      end

      def save_transfer
        failure(stock_transfer) unless stock_transfer.save
      end
    end
  end
end
