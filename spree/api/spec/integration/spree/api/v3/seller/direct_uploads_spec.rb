# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Direct Uploads API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one — this
  # is what a member of a seller's team actually holds on their own seller.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  path '/api/v3/seller/direct_uploads' do
    post 'Create a direct upload' do
      tags 'Uploads'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Presigns an upload target for a file the seller is about to send.

        Three steps: post the file's metadata here, `PUT` the bytes to the
        returned `direct_upload.url` with the headers it names, then send the
        returned `signed_id` wherever the file belongs — as a requirement
        submission's `file`, or as `logo`, `square_logo` or `cover_photo` on the
        profile.

        The blob is attached to nothing at this point. The endpoint that consumes
        the `signed_id` is the one that checks ownership.

        `checksum` is the file's MD5 digest, base64-encoded — the storage service
        verifies the upload against it.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          blob: {
            type: :object,
            properties: {
              filename: { type: :string, example: 'registration.pdf' },
              byte_size: { type: :integer, example: 51_234 },
              checksum: { type: :string, description: 'Base64-encoded MD5 digest of the file', example: 'rL0Y20zC+Fzt72VPzMSk2A==' },
              content_type: { type: :string, example: 'application/pdf' }
            },
            required: %w[filename byte_size checksum content_type]
          }
        },
        required: %w[blob]
      }

      response '201', 'upload target created' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) do
          {
            blob: {
              filename: 'registration.pdf',
              byte_size: 51_234,
              checksum: Digest::MD5.base64digest('registration'),
              content_type: 'application/pdf'
            }
          }
        end

        schema '$ref' => '#/components/schemas/DirectUploadResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['signed_id']).to be_present
          expect(data['direct_upload']['url']).to be_present
        end
      end
    end
  end
end
