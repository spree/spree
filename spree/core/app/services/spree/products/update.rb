module Spree
  module Products
    class Update
      prepend Spree::ServiceModule::Base

      def call(product:, store:, params:)
        ApplicationRecord.transaction do
          run :update_product
          run :update_variants
        end
      end

      private

      def update_product(product:, store:, params:)
        params = params.to_h.with_indifferent_access
        variants_params = params.delete(:variants)
        product_params = params

        # Map tags array to tag_list
        product_params[:tag_list] = product_params.delete(:tags) if product_params.key?(:tags)

        # Preserve taxon associations from other stores
        if product_params.key?(:taxon_ids)
          other_store_taxon_ids = product.taxons
                                         .joins(:taxonomy)
                                         .where.not(spree_taxonomies: { store_id: store.id })
                                         .pluck(:id)
          product_params[:taxon_ids] = (product_params[:taxon_ids] + other_store_taxon_ids).uniq
        end

        if product.update(product_params)
          success(product: product, store: store, variants_params: variants_params)
        else
          failure(product, product.errors)
        end
      end

      def update_variants(product:, store:, variants_params:)
        return success(product: product) if variants_params.blank?

        variants_params.each do |variant_data|
          variant_data = variant_data.to_h.with_indifferent_access
          variant_id = variant_data.delete(:id)

          if variant_id.present?
            variant = product.variants_including_master.find_by_prefix_id!(variant_id)
            result = Spree::Variants::Update.call(variant: variant, params: variant_data)
          else
            result = Spree::Variants::Create.call(product: product, params: variant_data)
          end

          return result unless result.success?
        end

        success(product: product.reload)
      end
    end
  end
end
