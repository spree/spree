module Spree
  module PurchaseOrders
    # Edits a draft order. Once it has been placed with the supplier, what was
    # ordered is a matter of record between two businesses — so this refuses
    # anything past `draft`.
    class Update < Spree::Workflow
      hooks :validate, :after_update

      # @param purchase_order [Spree::PurchaseOrder]
      # @param attributes [Hash] editable columns — supplier, destination,
      #   currency, expected date, reference, notes, metadata
      # @param items [Array<Hash>, nil] `[{ variant:, quantity_ordered:,
      #   unit_cost: }]` replacing the current lines; nil leaves them alone
      def perform(purchase_order:, attributes: {}, items: nil)
        super

        step :ensure_editable
        run_hooks :validate

        ApplicationRecord.transaction do
          step :apply_changes
          step :save_purchase_order
        end

        run_hooks :after_update
        success(purchase_order.reload)
      end

      private

      def ensure_editable
        return if purchase_order.editable?

        failure(purchase_order, Spree.t('purchase_order.errors.not_editable'))
      end

      def apply_changes
        purchase_order.assign_attributes(attributes) if attributes.present?
        return if items.nil?

        purchase_order.items.destroy_all
        Array(items).each do |item|
          purchase_order.items.build(
            variant: item[:variant],
            quantity_ordered: item[:quantity_ordered],
            unit_cost: item[:unit_cost]
          )
        end
      end

      def save_purchase_order
        failure(purchase_order) unless purchase_order.save
      end
    end
  end
end
