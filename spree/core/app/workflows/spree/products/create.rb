module Spree
  module Products
    # Creates a product. The single gate for product creation — the Admin
    # API, the CSV importer and seeds all run through it, so a :validate
    # handler sees every product a store gains rather than only the ones
    # typed into the dashboard.
    #
    # Product writes earn a workflow (rather than the plain CRUD the services
    # doctrine leaves alone) because creation is already orchestration:
    # nested variants, a delivery profile stamped from the product type, and
    # custom-field values that can only be written after the product exists.
    class Create < Spree::Workflow
      hooks :validate, :after_create

      # The unsaved record a :validate handler reads (with its `changes`).
      attr_reader :product

      # @param store [Spree::Store]
      # @param attributes [Hash] product attributes
      # @param record [Spree::Product, nil] an already-built unsaved product.
      #   The CSV importer assigns its own attributes across several steps and
      #   hands the record over rather than a hash.
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(store:, attributes: {}, record: nil)
        super

        step :build_product

        # Before the insert: a rejection costs no rollback, and a handler
        # reading `product` sees exactly what would have been saved.
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_product
          run_hooks :after_create
        end

        success(product)
      end

      private

      def build_product
        @product = record || store.products.new
        @product.assign_attributes(attributes) if attributes.present?
      end

      def save_product
        failure(product) unless product.save
      end
    end
  end
end
