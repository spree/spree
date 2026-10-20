module Spree
  module PurchaseOrders
    # Edits a draft order. Once it has been placed with the supplier, what was
    # ordered is a matter of record between two businesses — so this refuses
    # anything past `draft`.
    class Update < Spree::Workflow
      include Spree::Receivables::DraftEditing

      hooks :validate, :after_update

      # @param purchase_order [Spree::PurchaseOrder]
      # @param attributes [Hash] editable columns — supplier, destination,
      #   currency, expected date, reference, notes, metadata
      # @param items [Array<Hash>, nil] `[{ variant:, quantity_ordered:,
      #   unit_cost: }]` replacing the current lines; nil leaves them alone
      def perform(purchase_order:, attributes: {}, items: nil)
        super
        edit
      end

      private

      def receivable = purchase_order
      def item_attributes = %i[quantity_ordered unit_cost]
    end
  end
end
