module Spree
  module Api
    module V3
      module Admin
        class DirectUploadsController < Admin::BaseController
          include Spree::Api::V3::DirectUploads

          # Direct uploads is a write-adjacent presigning helper: callers exchange
          # blob metadata for an upload URL, then reference the resulting
          # signed_id when creating/updating a resource (product media, customer
          # avatar, etc). The narrowest scope it can map to is `write_products`
          # since that covers the dominant upload flow (product/variant media).
          # Other admin-write flows that take signed_ids (e.g. customer avatar)
          # already require the relevant `write_<resource>` scope on the
          # subsequent PATCH, so this gate is the floor, not the only check.
          scoped_resource :products

          skip_before_action :authenticate_user

          # POST /api/v3/admin/direct_uploads
          #
          # Overrides the shared concern's create to select the storage service:
          # digital assets must land on private storage up front, since attaching
          # a signed id never moves a blob between services.
          def create
            blob = ActiveStorage::Blob.create_before_direct_upload!(service_name: storage_service_name, **blob_params)

            render json: {
              direct_upload: {
                url: blob.service_url_for_direct_upload,
                headers: blob.service_headers_for_direct_upload
              },
              signed_id: blob.signed_id
            }, status: :created
          end

          private

          # Attaching a signed id never moves the blob between services, so a
          # file destined for a private attachment has to be uploaded to the
          # private service up front. `private: true` asks for that; everything
          # else keeps landing on the public service as before.
          def storage_service_name
            if params[:private].to_b
              Spree.private_storage_service_name
            else
              Spree.public_storage_service_name
            end
          end
        end
      end
    end
  end
end
