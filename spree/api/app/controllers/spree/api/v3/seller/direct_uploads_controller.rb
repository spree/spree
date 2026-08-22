module Spree
  module Api
    module V3
      module Seller
        # Presigning for a seller's own uploads — today the documents their
        # onboarding asks for.
        #
        # A blob created here is not attached to anything yet: it becomes a
        # submission only when the seller posts its signed id, and that
        # endpoint is the one that checks the requirement is theirs. So the
        # narrowest meaningful gate is the seller's own profile, which every
        # member of a seller's team holds.
        class DirectUploadsController < Seller::BaseController
          scoped_resource :seller_profile

          # POST /api/v3/seller/direct_uploads
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
