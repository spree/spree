module Spree
  module Api
    module V3
      # The downloadable files on one product, shared by the operator's and a
      # seller's branch. What differs is only how the including controller
      # reaches the product (`set_parent`) and which serializer answers.
      module DigitalAssetWrites
        extend ActiveSupport::Concern

        # PATCH .../products/:product_id/digital_assets/:id
        #
        # Replacing the file keeps every already-issued link working, since
        # links resolve through the asset rather than the blob.
        def update
          return render_private_storage_error unless uploaded_blob_private?

          # The asset already exists, so attaching a replacement blob writes
          # to the database immediately, while the update below renders a 422
          # without raising when it fails. Wrap both so a failed update rolls
          # the new attachment back rather than leaving the file swapped but
          # the record unchanged.
          model_class.transaction do
            @resource.variant = requested_variant if params[:variant_id].present?
            attach_uploaded_file(@resource)

            super

            raise ActiveRecord::Rollback if @resource.errors.any?
          end
        end

        # POST .../products/:product_id/digital_assets
        def create
          return render_private_storage_error unless uploaded_blob_private?

          super
        end

        protected

        def model_class
          Spree::DigitalAsset
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

        def permitted_params
          params.permit(*declared_permitted_attributes)
        end

        private

        # A product without explicit variants keeps its file on the default
        # variant, mirroring how the rest of the panels treat such products.
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
          render_validation_error(I18n.t('spree.digital_assets_attachment_must_be_private'))
        end
      end
    end
  end
end
