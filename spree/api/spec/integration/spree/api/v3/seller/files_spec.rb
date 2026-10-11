# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Files API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one — this
  # is what a member of a seller's team actually holds on their own seller.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  path '/api/v3/seller/files' do
    post 'Upload a file' do
      tags 'Files'
      consumes 'application/json', 'multipart/form-data'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Accepts a file and returns a `signed_id` to send wherever the file
        belongs — as a requirement submission's `file_signed_id`, or as
        `logo_signed_id`, `square_logo_signed_id` or `cover_photo_signed_id` on
        the profile. The file is attached to nothing at this point; the
        endpoint that takes the `signed_id` is the one that checks ownership.

        Send the file's metadata as JSON, then `PUT` the bytes to `upload.url`
        with exactly `upload.headers`; or send small files (10 MB by default)
        as a multipart `file` part, in which case `upload` is null.

        `signed_id` is opaque and expires at `expires_at`, one day after the
        upload. `visibility` is `public` (the default, web images, videos and
        CSV only) or `private` (any type). `checksum` is the file's MD5
        digest, base64-encoded.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          filename: { type: :string, example: 'registration.pdf' },
          content_type: { type: :string, example: 'application/pdf' },
          byte_size: { type: :integer, example: 51_234 },
          checksum: { type: :string, description: 'Base64-encoded MD5 digest of the file', example: 'rL0Y20zC+Fzt72VPzMSk2A==' },
          visibility: { type: :string, enum: %w[public private], default: 'public' },
          file: { type: :string, format: :binary, description: 'The bytes, for a multipart upload' }
        },
        required: %w[filename content_type]
      }

      response '201', 'upload target created' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) do
          {
            filename: 'registration.pdf',
            content_type: 'application/pdf',
            byte_size: 51_234,
            checksum: Digest::MD5.base64digest('registration'),
            visibility: 'private'
          }
        end

        schema SwaggerSchemaHelpers.ref('FileUpload')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['signed_id']).to be_present
          expect(data['upload']['url']).to be_present
          expect(ActiveStorage::Blob.find_signed(data['signed_id']).store_id).to eq(store.id)
        end
      end
    end
  end
end
