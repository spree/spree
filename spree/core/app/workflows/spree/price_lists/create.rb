module Spree
  module PriceLists
    # Creates a price list. The bulk payloads a list can arrive with — which
    # products it covers, and their price overrides — are applied by
    # Spree::PriceLists::Update once the row exists, since both paths reconcile
    # them the same way and membership has to settle before prices.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      attr_reader :price_list

      # @param store [Spree::Store]
      # @param attributes [Hash] may carry `product_ids` and `prices`
      # @return [Spree::ServiceModule::Result] value is the price list
      def perform(store:, attributes: {})
        super

        step :build_price_list
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_price_list
          step :apply_bulk_payloads
          run_hooks :after_create
        end

        success(price_list)
      end

      private

      # Held back from the new record so it saves as a plain row; the
      # collections are reconciled once it has an id.
      def build_price_list
        # See Spree::PriceLists::Update on the indifferent access.
        attrs = attributes.to_h.with_indifferent_access

        @bulk_payloads = attrs.slice(:product_ids, :prices)
        @price_list = store.price_lists.new(attrs.except(:product_ids, :prices))
      end

      def save_price_list
        failure(price_list) unless price_list.save
      end

      def apply_bulk_payloads
        return if @bulk_payloads.empty?

        result = Spree.price_list_update_workflow.call(price_list: price_list, attributes: @bulk_payloads)
        failure(price_list, result.error) unless result.success?
      end
    end
  end
end
