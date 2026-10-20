# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Purchase Order Document API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:cart) { create(:cart_with_line_items, store: store, customer: user) }

  path '/api/v3/store/carts/{cart_id}/po_document' do
    parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'

    post 'Upload a purchase order document' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Prepares an upload for the buyer's signed purchase order document. Send the
        file's metadata, then `PUT` the bytes to `upload.url` with exactly
        `upload.headers`, and attach the file by sending the returned `signed_id` as
        `po_document_signed_id` on a cart update. Files are stored privately.
        `checksum` is the file's MD5 digest, base64-encoded. Returns 422 when the
        declared size or type is not accepted for a purchase order.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      request_body_for

      response '201', 'upload target created' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:cart_id) { cart.prefixed_id }
        let(:body) do
          {
            filename: 'purchase-order.pdf',
            content_type: 'application/pdf',
            byte_size: 48_210,
            checksum: Digest::MD5.base64digest('purchase order')
          }
        end

        schema SwaggerSchemaHelpers.ref('FileUpload')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['signed_id']).to be_present
          expect(data['visibility']).to eq('private')
        end
      end
    end
  end
end
