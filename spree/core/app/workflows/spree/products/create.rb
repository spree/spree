module Spree
  module Products
    # Creates a product. The single gate for product creation — the Admin
    # API, the CSV importer and seeds all run through it, so a :validate
    # handler sees every product a store gains rather than only the ones
    # typed into the dashboard.
    #
    # Nested data a product arrives with — variants, media — cannot be
    # written until the product has an id, so the model's setters stash hash
    # payloads given to a new record and this replays them as a step of its
    # own. It used to be an after_create callback; as a step the two phases of
    # a create are visible where the flow is described rather than hidden in
    # the save.
    #
    # :validate still runs before the insert, and therefore before any
    # variant or image exists, so a rejection leaves nothing to clean up.
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
          step :apply_deferred_nested_attributes
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
        @product.assign_attributes(attributes) if attributes.present?
      end

      def save_product
        failure(product) unless product.save
      end

      # Variants and media the caller sent as hashes, which had to wait for
      # the product to exist.
      def apply_deferred_nested_attributes
        product.apply_deferred_nested_attributes
      end
    end
  end
end
