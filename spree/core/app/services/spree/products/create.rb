module Spree
  module Products
    class Create
      prepend Spree::ServiceModule::Base

      def call(store:, params:)
        ApplicationRecord.transaction do
          run :create_product
          run :create_variants
        end
      end

      private

      def create_product(store:, params:)
        params = params.to_h.with_indifferent_access
        variants_params = params.delete(:variants)
        product_params = params
        product_params[:store_ids] = [store.id] if product_params[:store_ids].blank?

        # Map tags array to tag_list
        product_params[:tag_list] = product_params.delete(:tags) if product_params.key?(:tags)

        # Extract IDs that after_initialize callbacks may overwrite
        tax_category_id = product_params.delete(:tax_category_id)
        shipping_category_id = product_params.delete(:shipping_category_id)

        product = Spree::Product.new(product_params)
        overrides = {}
        overrides[:tax_category_id] = tax_category_id if tax_category_id.present?
        overrides[:shipping_category_id] = shipping_category_id if shipping_category_id.present?
        product.assign_attributes(overrides) if overrides.any?

        if product.save
          success(product: product, store: store, variants_params: variants_params)
        else
          failure(product, product.errors)
        end
      end

      def create_variants(product:, store:, variants_params:)
        return success(product: product) if variants_params.blank?

        variants_params.each do |variant_data|
          result = Spree::Variants::Create.call(product: product, params: variant_data)
          return result unless result.success?
        end

        success(product: product.reload)
      end
    end
  end
end
