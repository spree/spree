module Spree
  module StockTransfers
    # Plans a transfer. Nothing moves: a draft is a packing list the merchant
    # can still edit, and stock only leaves the source warehouse when
    # {Spree::StockTransfers::MarkInTransit} runs.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      # The created transfer — hook handlers read it (nil while :validate runs).
      attr_reader :stock_transfer

      # @param store [Spree::Store]
      # @param source_location [Spree::StockLocation] where the goods leave from
      # @param destination_location [Spree::StockLocation] where they are going
      # @param items [Array<Hash>] `[{ variant:, quantity_shipped: }]`; a draft
      #   may legitimately open empty and gain lines as the merchant packs
      # @param reference [String, nil] the merchant's own label for the trip
      # @param notes [String, nil]
      # @param created_by [Object, nil]
      def perform(store:, source_location:, destination_location:, items: [],
                  reference: nil, notes: nil, created_by: nil)
        super

        step :build_transfer
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_transfer
        end

        run_hooks :after_create
        stock_transfer.publish_event('stock_transfer.created')
        success(stock_transfer.reload)
      end

      private

      def build_transfer
        @stock_transfer = store.stock_transfers.new(
          source_location: source_location,
          destination_location: destination_location,
          reference: reference,
          notes: notes,
          created_by: created_by,
          status: Spree::StockTransfer.default_status
        )

        Array(items).each do |item|
          @stock_transfer.items.build(variant: item[:variant], quantity_shipped: item[:quantity_shipped])
        end
      end

      # Line-level problems — a missing variant, a quantity of zero, the same
      # SKU twice — are model validations, so they answer with the field that
      # is wrong rather than one message about the whole document.
      def save_transfer
        failure(stock_transfer) unless stock_transfer.save
      end
    end
  end
end
