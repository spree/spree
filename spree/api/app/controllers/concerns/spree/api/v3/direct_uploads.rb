module Spree
  module Api
    module V3
      # Presigning for direct-to-storage uploads: a caller exchanges blob
      # metadata for an upload URL and gets back a signed id to reference when
      # it creates or updates a resource.
      #
      # Shared by the admin and seller branches because the exchange itself is
      # audience-neutral — a blob created here is attached to nothing. What
      # differs is the gate each branch puts in front of it, which stays on the
      # including controller as its `scoped_resource`.
      module DirectUploads
        extend ActiveSupport::Concern

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
