module Spree
  module Products
    # Updates a product, reconciling the variants and media the payload
    # carries (see Spree::Products::NestedAttributes — both are full
    # replacements).
    #
    # Handlers reading `product.changes` in :validate see the pending edit
    # before it is written, which is what makes rules like "price may not
    # drop below cost" expressible without a model validation.
    class Update < Spree::Workflow
      include Spree::Products::NestedAttributes

      hooks :validate, :after_update

      # `product` — the record with the pending attributes assigned, so a
      # :validate handler reads `product.changes` to see the edit.

      # @param product [Spree::Product]
      # @param attributes [Hash]
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:, attributes: {})
        super

        step :assign_attributes
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_product
          step :apply_nested_attributes
          run_hooks :after_update
        end

        success(product)
      end

      private

      def assign_attributes
        # See Spree::Products::Create — string-keyed hashes reach this from
        # host apps and importers, and a missed key would send the nested
        # payload to the ActiveRecord collection setter instead.
        attrs = attributes.to_h.with_indifferent_access

        # Held back: variants and media are reconciled after the save, so a
        # :validate handler reads `product.changes` describing the edit itself
        # rather than a half-applied collection.
        @variants_params = attrs[:variants]
        @media_params = attrs[:media]
        @digital_assets_params = attrs[:digital_assets]
        product.assign_attributes(attrs.except(:variants, :media, :digital_assets))
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
