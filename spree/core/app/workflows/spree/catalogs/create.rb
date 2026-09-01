module Spree
  module Catalogs
    # Creates a catalog, and the price list it prices through when one rides
    # along in the payload. Standing up an agreement is one request: a
    # merchant naming an audience and a discount never has to visit the
    # price-lists page to finish (docs/plans/6.0-catalog-agreement-rework.md).
    class Create < Spree::Workflow
      hooks :validate, :after_create

      attr_reader :catalog

      # @param store [Spree::Store]
      # @param attributes [Hash] may carry `price_list`
      # @return [Spree::ServiceModule::Result] value is the catalog
      def perform(store:, attributes: {})
        super

        step :build_catalog
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_catalog
          step :apply_price_list
          step :apply_assignments
          step :apply_order_minimums
          run_hooks :after_create
        end

        success(catalog)
      end

      private

      # The list payload is held back rather than assigned: the catalog needs
      # an id before a list can point at it.
      # The nested sets are held back rather than assigned: they are applied
      # inside the save's transaction, once the catalog has an id to point at.
      def build_catalog
        attrs = attributes.to_h.with_indifferent_access

        @price_list_attributes = attrs.key?(:price_list) ? attrs[:price_list] : nil
        @assignables = attrs[:assignables]
        @order_minimums = attrs[:order_minimums]

        @catalog = store.catalogs.new(attrs.except(:price_list, :assignables, :order_minimums))
      end

      # A catalog can be created with its audience and minimums already
      # stated, so standing one up is a single request the way the price list
      # already is.
      def apply_assignments
        return if @assignables.blank?

        result = Spree::Catalogs::SetAssignments.call(catalog: catalog, assignables: @assignables)
        failure(catalog, result.error) unless result.success?
      end

      def apply_order_minimums
        return if @order_minimums.blank?

        result = Spree::Catalogs::SetOrderMinimums.call(
          catalog: catalog, order_minimums: @order_minimums
        )
        failure(catalog, result.error) unless result.success?
      end

      def save_catalog
        failure(catalog) unless catalog.save
      end

      def apply_price_list
        return if @price_list_attributes.blank?

        result = Spree.catalog_price_list_workflow.call(
          catalog: catalog, attributes: @price_list_attributes
        )
        # Pass the inner ResultError through rather than wrapping it, so the
        # ActiveModel::Errors a 422 is built from survive.
        failure(catalog, result.error.value) unless result.success?
      end
    end
  end
end
