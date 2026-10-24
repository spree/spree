module Spree
  module Api
    module V3
      module Seller
        module Products
          # The downloadable files on one of this seller's own products.
          #
          # Uploaded files only: a provider is the operator's own code
          # reaching into their internal systems, so a seller can neither pick
          # one nor read its settings. An asset the operator set up with one
          # is still listed, since it is part of what the seller's product
          # delivers.
          class DigitalAssetsController < Seller::ResourceController
            include Spree::Api::V3::DigitalAssetWrites

            scoped_resource :products

            request_params :digital_asset do |body|
              body.include_attributes Spree::Api::V3::DigitalAssetRequestSchema
            end

            protected

            def serializer_class
              Spree.api.seller_digital_asset_serializer
            end

            # Rooted in the seller's own catalog, so another seller's product
            # is a 404. Changing a product's files is a change to the product,
            # so writes need `:update` on it, not just `:show`.
            def set_parent
              @parent = current_seller.products.find_by_prefix_id!(params[:product_id])
              authorize_parent!(@parent)
            end
          end
        end
      end
    end
  end
end
