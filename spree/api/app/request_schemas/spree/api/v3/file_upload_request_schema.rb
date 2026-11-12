module Spree
  module Api
    module V3
      # A file sent to `POST /files` (Spree::Api::V3::FileUploads): its
      # details for a direct upload, or its bytes in a multipart request.
      class FileUploadRequestSchema < Spree::Api::V3::RequestSchema
        attribute :filename, :string, required: true, example: 'registration.pdf'
        attribute :content_type, :string, required: true, example: 'application/pdf'
        attribute :byte_size, :integer, example: 51_234
        attribute :checksum, :string,
          example: 'rL0Y20zC+Fzt72VPzMSk2A==',
          description: 'Base64-encoded MD5 digest of the file; the storage service checks the bytes against it.'
        attribute :visibility, :string,
          choices: Spree::FileUpload::VISIBILITIES,
          description: '`public` (the default) for images, videos and CSV files anyone may fetch, `private` for any type.'
        attribute :file, :string, format: :binary, description: 'The bytes, for a multipart upload.'
      end
    end
  end
end
