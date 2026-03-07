# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Product Assets API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, stores: [store]) }
  let!(:image) { create(:image, viewable: product.master) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/products/{product_id}/assets' do
    get 'List product assets' do
      tags 'Product Assets'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of assets (images) for a product.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'assets found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a product asset' do
      tags 'Product Assets'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new asset (image) for a product.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          alt: { type: :string, example: 'Product front view' },
          position: { type: :integer, example: 1 },
          type: { type: :string, example: 'Spree::Image', description: 'Asset type (defaults to Spree::Image)' },
          url: { type: :string, example: 'https://example.com/image.jpg', description: 'External URL to import image from (async). Returns 202 Accepted.' }
        }
      }

      response '202', 'asset import from URL enqueued' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:body) { { url: 'https://example.com/image.jpg', position: 1 } }

        run_test!
      end

      response '422', 'validation error (attachment required)' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:body) { { alt: 'New product image', position: 1 } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/products/{product_id}/assets/{id}' do
    patch 'Update a product asset' do
      tags 'Product Assets'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a product asset. Only provided fields are updated.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Asset prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          alt: { type: :string, example: 'Updated alt text' },
          position: { type: :integer, example: 2 }
        }
      }

      response '200', 'asset updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:id) { image.prefixed_id }
        let(:body) { { alt: 'Updated alt text' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['alt']).to eq('Updated alt text')
        end
      end
    end

    delete 'Delete a product asset' do
      tags 'Product Assets'
      security [api_key: [], bearer_auth: []]
      description 'Deletes an asset from a product.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Asset prefixed ID'

      response '204', 'asset deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:id) { image.prefixed_id }

        run_test!
      end
    end
  end
end
