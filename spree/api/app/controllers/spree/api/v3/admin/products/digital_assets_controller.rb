module Spree
  module Api
    module V3
      module Admin
        module Products
          class DigitalAssetsController < ResourceController
            scoped_resource :products

            # PATCH /api/v3/admin/products/:product_id/digital_assets/:id
            #
            # Replacing the file keeps every already-issued link working, since
            # links resolve through the asset rather than the blob.
            def update
              attach_uploaded_file(@resource)

              super
            end

            protected

            def model_class
              Spree::DigitalAsset
            end

            def serializer_class
              Spree.api.admin_digital_asset_serializer
            end

            def set_parent
              @parent = current_store.products.find_by_prefix_id!(params[:product_id])
              authorize!(:show, @parent)
            end

            def parent_association
              :digital_assets
            end

            def scope_includes
              [:variant, { attachment_attachment: :blob }]
            end

            # signed_id names an already-uploaded blob rather than a column, so
            # it is attached separately instead of being assigned.
            def permitted_params
              params.permit(:variant_id, :authorized_clicks, :authorized_days)
            end

            private

            # A product without explicit variants keeps its file on the default
            # variant, mirroring how the rest of the admin treats such products.
            def build_resource
              digital_asset = super
              digital_asset.variant ||= @parent.default_variant
              attach_uploaded_file(digital_asset)
              digital_asset
            end

            def attach_uploaded_file(digital_asset)
              return if params[:signed_id].blank?

              digital_asset.attachment.attach(params[:signed_id])
            end
          end
        end
      end
    end
  end
end
