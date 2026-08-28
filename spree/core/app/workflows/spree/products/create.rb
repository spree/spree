module Spree
  module Products
    # Creates a product. The single gate for product creation — the Admin
    # API, the CSV importer and seeds all run through it, so a :validate
    # handler sees every product a store gains rather than only the ones
    # typed into the dashboard.
    #
    # Nested data — variants and media — is applied here rather than by the
    # model, because it cannot be written until the product has an id and
    # because it is a reconciliation, not an assignment: the payload is the
    # writer's whole intent and variants missing from it are removed.
    #
    # :validate runs before the insert, and therefore before any variant or
    # image exists, so a rejection leaves nothing to clean up.
    class Create < Spree::Workflow
      include Spree::Products::NestedAttributes

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
          step :apply_nested_attributes
          run_hooks :after_create
        end

        success(product)
      end

      private

      def build_product
        @product = record || store.products.new
        # A supplied record must belong to the store the caller named — a
        # product resolved outside that scope would otherwise be persisted
        # against the wrong tenant, and every :validate handler reading
        # `store` would be told the wrong thing.
        @product.store = store
        return if attributes.blank?

        # Indifferent access because this is a public entry point: a host app
        # or importer passing a plain string-keyed hash must not have its
        # nested payloads fall through to the ActiveRecord collection setters.
        attrs = attributes.to_h.with_indifferent_access

        # Held back from the record: these are reconciled after the insert,
        # against a product that has an id.
        @variants_params = attrs[:variants]
        @media_params = attrs[:media]
        @digital_assets_params = attrs[:digital_assets]
        @product.assign_attributes(attrs.except(:variants, :media, :digital_assets))
      end

      def save_product
        failure(product) unless product.save
      end

      def apply_nested_attributes
        apply_variants(product, @variants_params)
        apply_media(product, @media_params)
        apply_digital_assets(product, @digital_assets_params)
      end
    end
  end
end
