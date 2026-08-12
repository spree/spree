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

              @resource.variant = requested_variant if params[:variant_id].present?
              attach_uploaded_file(@resource)

              super
            end

            # POST /api/v3/admin/products/:product_id/digital_assets
            def create
              return render_private_storage_error unless uploaded_blob_private?

              super
            end

            # GET /api/v3/admin/products/:product_id/digital_assets/providers
            #
            # The sources a merchant can pick for a new asset: the uploaded-file
            # default plus any host-registered provider. Drives the dashboard's
            # source selector; a host with only the default sees just "upload".
            def providers
              authorize! :create, model_class

              data = Spree.digital_asset_providers.map do |provider_class|
                {
                  type: provider_class.to_s,
                  name: provider_class.provider_name,
                  requires_attachment: provider_class.requires_attachment?,
                  settings_schema: provider_class.settings_schema
                }
              end

              render json: { data: data }
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

            # The parent association reaches assets through `variants`, which
            # carries an ORDER BY on the variants table. Combined with the
            # collection's DISTINCT, PostgreSQL rejects the query outright
            # (ordering columns must appear in the select list), so order by
            # the assets' own table instead. SQLite accepts either form, so
            # this only fails on a real deployment.
            def scope
              super.reorder(created_at: :asc)
            end

            def scope_includes
              [:variant, { attachment_attachment: :blob }]
            end

            # variant_id is resolved through the parent rather than assigned:
            # mass-assigning it would let a caller point an asset at a variant
            # of any product, in any store. signed_id likewise names a blob
            # rather than a column, so it is attached separately.
            # provider_type is mass-assignable: the model validates it names a
            # registered provider, so an unknown value is a 422, not a hazard.
            # provider_settings is an open hash — its keys are declared by the
            # provider, not fixed here — so it is permitted as arbitrary scalars
            # and lands verbatim under one key in the asset's metadata.
            def permitted_params
              params.permit(:authorized_clicks, :authorized_days, :provider_type, provider_settings: {})
            end

            private

            # A product without explicit variants keeps its file on the default
            # variant, mirroring how the rest of the admin treats such products.
            def build_resource
              digital_asset = super
              digital_asset.variant = requested_variant || @parent.default_variant
              attach_uploaded_file(digital_asset)
              digital_asset
            end

            # Scoped to the parent, not merely to the store: an asset reached
            # through a product's route has no business pointing at another
            # product's variant. An id from anywhere else is a 404.
            def requested_variant
              return if params[:variant_id].blank?

              @parent.variants.find_by_prefix_id!(params[:variant_id])
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
