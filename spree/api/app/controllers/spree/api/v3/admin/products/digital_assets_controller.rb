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
              return render_private_storage_error unless uploaded_blob_private?

              attach_uploaded_file(@resource)

              super
            end

            # POST /api/v3/admin/products/:product_id/digital_assets
            def create
              return render_private_storage_error unless uploaded_blob_private?

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

            # Attaching never moves a blob between storage services, so a file
            # uploaded to the public bucket would stay publicly readable while
            # looking attached. Refuse it rather than storing it wrongly.
            def uploaded_blob_private?
              return true if params[:signed_id].blank?

              blob = ActiveStorage::Blob.find_signed(params[:signed_id])
              blob.present? && blob.service_name.to_s == Spree.private_storage_service_name.to_s
            end

            def render_private_storage_error
              render_validation_error(Spree.t('digital_assets.attachment_must_be_private'))
            end
          end
        end
      end
    end
  end
end
