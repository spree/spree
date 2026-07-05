module Spree
  module Api
    module V3
      module Admin
        class DirectUploadsController < Admin::BaseController
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
          def create
            blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_params)

            render json: {
              direct_upload: {
                url: blob.service_url_for_direct_upload,
                headers: blob.service_headers_for_direct_upload
              },
              signed_id: blob.signed_id
            }, status: :created
          end

          private

          def blob_params
            params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type).to_h.symbolize_keys
          end
        end
      end
    end
  end
end
