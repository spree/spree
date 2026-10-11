module Spree
  module Api
    module V3
      module Seller
        # A file stored here is attached to nothing until the seller sends its
        # `signed_id` to an endpoint that checks the target is theirs, so the
        # narrowest meaningful gate is the seller's own profile, which every
        # member of a seller's team holds.
        class FilesController < Seller::BaseController
          include Spree::Api::V3::FileUploads

          scoped_resource :seller_profile

          # Documented only: the shared FileUploads concern does the permitting.
          request_params 'FileUploadCreateParams', action: :create do
            string :filename, required: true, permit: false, example: 'registration.pdf'
            string :content_type, required: true, permit: false, example: 'application/pdf'
            integer :byte_size, permit: false, example: 51_234
            string :checksum, permit: false, example: 'rL0Y20zC+Fzt72VPzMSk2A==',
                              description: 'Base64-encoded MD5 digest of the file; the storage service checks the bytes against it.'
            string :visibility, permit: false, enum: Spree::FileUpload::VISIBILITIES,
                                description: '`public` (the default) for web images, videos and CSV, `private` for any type.'
            string :file, permit: false, format: :binary, description: 'The bytes, for a multipart upload.'
          end

          private

          def file_upload_serializer
            Spree.api.seller_file_upload_serializer
          end
        end
      end
    end
  end
end
