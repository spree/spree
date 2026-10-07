module Spree
  module StockTransfers
    # Edits a draft transfer. Once the box is marked ready what is in it is a
    # matter of record, so this refuses anything past `draft` rather than
    # quietly rewriting a document the warehouse is already acting on.
    class Update < Spree::Workflow
      include Spree::Receivables::DraftEditing

      hooks :validate, :after_update

      # @param stock_transfer [Spree::StockTransfer]
      # @param attributes [Hash] editable columns — reference, notes, the two
      #   locations, metadata
      # @param items [Array<Hash>, nil] `[{ variant:, quantity_shipped: }]`
      #   replacing the current lines; nil leaves them alone
      def perform(stock_transfer:, attributes: {}, items: nil)
        super
        edit
      end

      private

      def receivable = stock_transfer
      def item_attributes = %i[quantity_shipped]
    end
  end
end
