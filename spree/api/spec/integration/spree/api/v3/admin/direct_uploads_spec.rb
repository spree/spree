# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Direct Uploads API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  path '/api/v3/admin/direct_uploads' do
    post 'Upload a file' do
      tags 'Uploads'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: [], api_key_auth: []]
      description <<~DESC
        Stores a file and answers with the `signed_id` to send wherever it
        belongs — a product's media, an import's `attachment`, an order's
        `po_document`.

        Two ways in. Send `blob` metadata and the response carries a presigned
        target: `PUT` the bytes to `direct_upload.url` with the headers it
        names, which is what a browser does. Send `content` and the bytes are
        stored here, which is what a caller that cannot make a second request
        needs.

        Text travels as text. Set `encoding` to `base64` for an image, a PDF or
        anything else that is not text — base64 is a third larger, and a caller
        generating the request pays for every byte of it.

        The blob is attached to nothing at this point. The endpoint that
        consumes the `signed_id` is the one that checks what it may be
        attached to.

        `checksum`, on the metadata form, is the file's MD5 digest
        base64-encoded; the storage service verifies the upload against it.
      DESC

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          blob: {
            type: :object,
            description: 'Metadata form: answers with a presigned upload target.',
            properties: {
              filename: { type: :string, example: 'catalogue.csv' },
              byte_size: { type: :integer, example: 51_234 },
              checksum: { type: :string, description: 'Base64-encoded MD5 digest of the file',
                          example: 'rL0Y20zC+Fzt72VPzMSk2A==' },
              content_type: { type: :string, example: 'text/csv' }
            },
            required: %w[filename byte_size checksum content_type]
          },
          filename: { type: :string, description: 'Bytes form: the file name, with its extension',
                      example: 'catalogue.csv' },
          content: { type: :string, description: 'Bytes form: the file itself, as text or base64',
                     example: "sku,name,price\nA-1,Thing,9.99\n" },
          encoding: { type: :string, enum: %w[base64],
                      description: 'Omit for text; `base64` for a binary file' },
          content_type: { type: :string, description: 'Read from the bytes when omitted',
                          example: 'text/csv' },
          private: { type: :boolean,
                     description: 'Store privately, for a file served only through an authenticated action' }
        }
      }

      response '201', 'file stored' do
        let(:Authorization) { "Bearer #{admin_jwt_token}" }
        let(:body) do
          { filename: 'catalogue.csv', content: "sku,name,price\nA-1,Thing,9.99\n", private: true }
        end

        schema type: :object,
               properties: {
                 signed_id: { type: :string, description: 'Send this wherever the file belongs' },
                 filename: { type: :string },
                 content_type: { type: :string },
                 byte_size: { type: :integer }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['signed_id']).to be_present
          expect(data['content_type']).to eq('text/csv')
        end
      end

      response '201', 'upload target created' do
        let(:Authorization) { "Bearer #{admin_jwt_token}" }
        let(:body) do
          {
            blob: {
              filename: 'catalogue.csv', byte_size: 51_234,
              checksum: Digest::MD5.base64digest('catalogue'), content_type: 'text/csv'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['direct_upload']['url']).to be_present
        end
      end

      response '422', 'the file is not a kind this endpoint accepts' do
        let(:Authorization) { "Bearer #{admin_jwt_token}" }
        let(:body) { { filename: 'script.sh', content: "#!/bin/sh\nrm -rf /\n" } }

        run_test!
      end
    end
  end
end
