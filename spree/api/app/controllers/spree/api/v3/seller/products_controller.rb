module Spree
  module Api
    module V3
      module Seller
        # A seller's own products.
        #
        # The first consumer of `Seller::ResourceController`, and the shape
        # every seller-side collection follows: the anchor roots `scope` in
        # `current_seller.products`, so listing, finding, updating and
        # deleting can only ever touch this seller's rows — a product id that
        # belongs to another seller is a 404, not a 403, since the caller
        # cannot tell whether it exists.
        #
        # Owned products only. Variants a seller lists against a shared
        # master-catalog product are a separate surface (the shared catalog
        # phase) and do not belong to this seller through `products`.
        #
        # What a seller may change is narrower than the operator's set:
        # `tax_category_id` and `delivery_profile_id` are marketplace
        # configuration and stay with the operator, as does `promotionable`.
        class ProductsController < Seller::ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.seller_product_serializer
          end

          def permitted_params
            params.permit(
              :name, :description, :slug, :status,
              :meta_title, :meta_description, :meta_keywords,
              :product_type_id,
              tags: [],
              category_ids: [],
              metadata: {},
              prices: [:amount, :compare_at_amount, :currency]
            )
          end

          def collection_includes
            [:default_variant, :primary_media]
          end
        end
      end
    end
  end
end
