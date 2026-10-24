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
              body.require_attributes :signed_id, on: :create
            end

            # PATCH /api/v3/seller/products/:product_id/digital_assets/:id
            #
            # A provider-backed asset delivers through the operator's provider,
            # so a file attached to it would show here but never reach a buyer.
            def update
              if params[:signed_id].present? && !@resource.provider_class.requires_attachment?
                return render_validation_error(I18n.t('spree.digital_assets_provider_takes_no_file'))
              end

              super
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
