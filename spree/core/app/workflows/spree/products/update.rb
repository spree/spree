module Spree
  module Products
    # Updates a product. Nested data is assigned by the model's own setters
    # (see Spree::Products::Create); this exists for the veto point.
    #
    # Handlers reading `product.changes` in :validate see the pending edit
    # before it is written, which is what makes rules like "price may not
    # drop below cost" expressible without a model validation.
    class Update < Spree::Workflow
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
          step :apply_deferred_nested_attributes
          run_hooks :after_update
        end

        success(product)
      end

      private

      def assign_attributes
        product.assign_attributes(attributes)
      end

      def save_product
        failure(product) unless product.save
      end

      # A no-op on a persisted product, whose setters apply immediately; here
      # so both write paths read the same.
      def apply_deferred_nested_attributes
        product.apply_deferred_nested_attributes
      end
    end
  end
end
