module Spree
  module Api
    module V3
      module Admin
        class DirectUploadsController < Admin::BaseController
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
