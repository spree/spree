module Spree
  module Catalogs
    # Updates a catalog, and the price list it prices through when one rides
    # along in the payload (docs/plans/6.0-catalog-agreement-rework.md).
    class Update < Spree::Workflow
      hooks :validate, :after_update

      # @param catalog [Spree::Catalog]
      # @param attributes [Hash] may carry `price_list`, `assignments` and
      #   `order_minimums` — small bounded sets the agreement editor saves
      #   with the catalog, so the whole agreement lands in one transaction
      #   rather than a sequence a failure can leave half applied
      # @return [Spree::ServiceModule::Result] value is the catalog
      def perform(catalog:, attributes: {})
        super

        step :assign_attributes
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_catalog
          step :apply_price_list
          step :apply_assignments
          step :apply_order_minimums
          run_hooks :after_update
        end

        success(catalog)
      end

      private

      # The nested sets are held back rather than assigned: they are applied
      # inside the save's transaction, so a catalog that fails validation
      # changes neither its audience nor its minimums.
      def assign_attributes
        attrs = attributes.to_h.with_indifferent_access

        @price_list_attributes = attrs.key?(:price_list) ? attrs[:price_list] : nil
        @assignables = attrs[:assignables]
        @order_minimums = attrs[:order_minimums]

        catalog.assign_attributes(attrs.except(:price_list, :assignables, :order_minimums))
      end

      def save_catalog
        failure(catalog) unless catalog.save
      end

      def apply_price_list
        return unless @price_list_attributes || price_list_key_present?

        result = Spree.catalog_price_list_workflow.call(
          catalog: catalog, attributes: @price_list_attributes
        )
        failure(catalog, result.error.value) unless result.success?
      end

      # `price_list: null` is a detach, which is a different thing from
      # sending no `price_list` key at all.
      def price_list_key_present?
        attributes.to_h.with_indifferent_access.key?(:price_list)
      end

      # Both are whole-set writes: an entry absent from the payload is
      # withdrawn. Omitting the key entirely leaves the set alone, so a
      # caller updating only a catalog's name touches neither.
      def apply_assignments
        return if @assignables.nil?

        result = Spree::Catalogs::SetAssignments.call(catalog: catalog, assignables: @assignables)
        failure(catalog, result.error) unless result.success?
      end

      def apply_order_minimums
        return if @order_minimums.nil?

        result = Spree::Catalogs::SetOrderMinimums.call(
          catalog: catalog, order_minimums: @order_minimums
        )
        failure(catalog, result.error) unless result.success?
      end
    end
  end
end
