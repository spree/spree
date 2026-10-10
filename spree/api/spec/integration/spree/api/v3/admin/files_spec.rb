# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Files API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/files' do
    post 'Upload a file' do
      tags 'Files'
      consumes 'application/json', 'multipart/form-data'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Accepts a file and returns a `signed_id` to send to the endpoint that
        uses it — `signed_id` on product media, `avatar_signed_id` on a
        customer, `attachment_signed_id` on an import, and so on.

        Two ways to send the bytes, one response:

        - **Presigned** (JSON): send the file's metadata, then `PUT` the bytes
          to `upload.url` with exactly `upload.headers`. Use this for anything
          large — the bytes go straight to storage.
        - **Multipart**: send the bytes in a `file` part. The file is stored
          before the response, so `upload` is null. Limited to 10 MB by default.

        `signed_id` is opaque: pass it back unchanged and never parse it. It
        stops being attachable at `expires_at`, one day after the upload.

        `visibility` picks the storage: `public` (the default) for images and
        videos customers see, `private` for documents, imports and digital
        products. Public uploads accept web images, videos and CSV; private
        uploads accept any type. `checksum` is the file's MD5 digest,
        base64-encoded — the storage service verifies the bytes against it.
      DESC
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          filename: { type: :string, example: 'products.csv' },
          content_type: { type: :string, example: 'text/csv' },
          byte_size: { type: :integer, example: 48_213 },
          checksum: { type: :string, description: 'Base64-encoded MD5 digest of the file', example: 'rL0Y20zC+Fzt72VPzMSk2A==' },
          visibility: { type: :string, enum: %w[public private], default: 'public' },
          file: { type: :string, format: :binary, description: 'The bytes, for a multipart upload' }
        },
        required: %w[filename content_type]
      }

      response '201', 'presigned upload target created' do
        let(:body) do
          {
            filename: 'products.csv',
            content_type: 'text/csv',
            byte_size: 48_213,
            checksum: Digest::MD5.base64digest('products'),
            visibility: 'private'
          }
        end

        schema SwaggerSchemaHelpers.ref('FileUpload')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['signed_id']).to be_present
          expect(data['visibility']).to eq('private')
          expect(data['upload']['method']).to eq('PUT')
          expect(data['upload']['url']).to be_present
          expect(ActiveStorage::Blob.find_signed(data['signed_id']).store_id).to eq(store.id)
        end
      end

      response '422', 'content type not allowed for a public upload' do
        let(:body) do
          { filename: 'script.sh', content_type: 'application/x-sh', byte_size: 12, checksum: Digest::MD5.base64digest('x') }
        end

        schema SwaggerSchemaHelpers.ref('ErrorResponse')

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['details']).to have_key('content_type')
        end
      end
    end
  end
end
