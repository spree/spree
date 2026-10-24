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
          #
          # The marketplace's rules for a seller's file — whether sellers may
          # upload at all, which content types, and whether an approved
          # listing goes back to review — apply because the workflow is told
          # who is writing.
          class DigitalAssetsController < Seller::ResourceController
            include Spree::Api::V3::DigitalAssetsResource

            scoped_resource :products

            request_params :digital_asset do |body|
              body.include_attributes Spree::Api::V3::DigitalAssetRequestSchema
              body.require_attributes :signed_id, on: :create
            end

            # DELETE /api/v3/seller/products/:product_id/digital_assets/:id
            #
            # Removing a file is covered by the same switch as adding one: a
            # marketplace that keeps digital files to itself keeps the ones it
            # attached to a seller's product.
            def destroy
              unless current_store.preferred_seller_digital_assets_enabled
                return render_validation_error(I18n.t('spree.digital_assets_sellers_disabled'))
              end

              super
            end

            protected

            def serializer_class
              Spree.api.seller_digital_asset_serializer
            end

            def create_workflow_arguments
              super.merge(seller: current_seller, submitted_by: current_user)
            end

            def update_workflow_arguments
              super.merge(seller: current_seller, submitted_by: current_user)
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
