module Spree
  module PurchaseOrders
    # Drafts an order to a supplier. Nothing is on order yet and nothing
    # touches availability — a draft is what the merchant is still deciding to
    # buy.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      # The created order — hook handlers read it (nil while :validate runs).
      attr_reader :purchase_order

      # @param store [Spree::Store]
      # @param supplier [Spree::Supplier]
      # @param destination_location [Spree::StockLocation] where the goods are
      #   expected
      # @param items [Array<Hash>] `[{ variant:, quantity_ordered:, unit_cost: }]`
      # @param currency [String, nil] defaults to the store's; set it for a
      #   foreign-currency order
      # @param expected_at [Date, nil]
      # @param reference [String, nil] the supplier's own order number
      # @param notes [String, nil]
      # @param created_by [Object, nil]
      def perform(store:, supplier:, destination_location:, items: [], currency: nil,
                  expected_at: nil, reference: nil, notes: nil, created_by: nil)
        super

        step :build_purchase_order
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_purchase_order
        end

        run_hooks :after_create
        purchase_order.publish_event('purchase_order.created')
        success(purchase_order.reload)
      end

      private

      def build_purchase_order
        @purchase_order = store.purchase_orders.new(
          supplier: supplier,
          destination_location: destination_location,
          currency: currency,
          expected_at: expected_at,
          reference: reference,
          notes: notes,
          created_by: created_by,
          status: Spree::PurchaseOrder.default_status
        )

        Array(items).each do |item|
          @purchase_order.items.build(
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
