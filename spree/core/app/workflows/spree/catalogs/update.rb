module Spree
  module Catalogs
    # Updates a catalog, and the price list it prices through when one rides
    # along in the payload (docs/plans/6.0-catalog-agreement-rework.md).
    class Update < Spree::Workflow
      hooks :validate, :after_update

      # @param catalog [Spree::Catalog]
      # @param attributes [Hash] may carry `price_list`
      # @return [Spree::ServiceModule::Result] value is the catalog
      def perform(catalog:, attributes: {})
        super

        step :assign_attributes
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_catalog
          step :apply_price_list
          run_hooks :after_update
        end

        success(catalog)
      end

      private

      def assign_attributes
        attrs = attributes.to_h.with_indifferent_access

        @price_list_attributes = attrs.key?(:price_list) ? attrs[:price_list] : nil
        catalog.assign_attributes(attrs.except(:price_list))
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
    end
  end
end
