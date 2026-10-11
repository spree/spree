module Spree
  module Api
    module V3
      module Admin
        class FilesController < Admin::BaseController
          include Spree::Api::V3::FileUploads

          # The endpoint that uses a file checks its own scope (`write_customers`
          # for an avatar, and so on), so this gate is the floor, not the only
          # check. `write_products` covers the dominant flow, product media.
          scoped_resource :products

          skip_before_action :authenticate_user

          # Permitted by Spree::Api::V3::FileUploads, shared with the seller branch.
          request_params 'FileUploadCreateParams', action: :create do
            string :filename, required: true, permit: false, example: 'products.csv'
            string :content_type, required: true, permit: false, example: 'text/csv'
            integer :byte_size, permit: false, example: 48_213
            string :checksum, permit: false, example: 'rL0Y20zC+Fzt72VPzMSk2A==',
                              description: 'Base64-encoded MD5 digest of the file; the storage service checks the bytes against it.'
            string :visibility, permit: false, enum: Spree::FileUpload::VISIBILITIES,
                                description: '`public` (the default) for images and videos customers see, `private` for anything else.'
            string :file, permit: false, format: :binary, description: 'The bytes, for a multipart upload.'
          end

          private

          def file_upload_serializer
            Spree.api.admin_file_upload_serializer
          end
        end
      end
    end
  end
end
