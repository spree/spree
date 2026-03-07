# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Variant Assets API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, stores: [store]) }
  let!(:variant) { create(:variant, product: product) }
  let!(:variant_image) { create(:image, viewable: variant) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/products/{product_id}/variants/{variant_id}/assets' do
    get 'List variant assets' do
      tags 'Variant Assets'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of assets (images) for a variant.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :variant_id, in: :path, type: :string, required: true, description: 'Variant prefixed ID'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'variant assets found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:variant_id) { variant.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          ids = data['data'].map { |a| a['id'] }
          expect(ids).to include(variant_image.prefixed_id)
        end
      end
    end

    post 'Create a variant asset' do
      tags 'Variant Assets'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new asset (image) for a variant.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :variant_id, in: :path, type: :string, required: true, description: 'Variant prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          alt: { type: :string, example: 'Variant image' },
          position: { type: :integer, example: 1 },
          type: { type: :string, example: 'Spree::Image', description: 'Asset type (defaults to Spree::Image)' },
          url: { type: :string, example: 'https://example.com/image.jpg', description: 'External URL to import image from (async). Returns 202 Accepted.' }
        }
      }

      response '202', 'variant asset import from URL enqueued' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:variant_id) { variant.prefixed_id }
        let(:body) { { url: 'https://example.com/variant.jpg', position: 1 } }

        run_test!
      end

      response '422', 'validation error (attachment required)' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:variant_id) { variant.prefixed_id }
        let(:body) { { alt: 'New variant image', position: 1 } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/products/{product_id}/variants/{variant_id}/assets/{id}' do
    patch 'Update a variant asset' do
      tags 'Variant Assets'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a variant asset. Only provided fields are updated.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :variant_id, in: :path, type: :string, required: true, description: 'Variant prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Asset prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          alt: { type: :string, example: 'Updated variant image' },
          position: { type: :integer, example: 2 }
        }
      }

      response '200', 'variant asset updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:variant_id) { variant.prefixed_id }
        let(:id) { variant_image.prefixed_id }
        let(:body) { { alt: 'Updated variant image' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['alt']).to eq('Updated variant image')
        end
      end
    end

    delete 'Delete a variant asset' do
      tags 'Variant Assets'
      security [api_key: [], bearer_auth: []]
      description 'Deletes an asset from a variant.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :variant_id, in: :path, type: :string, required: true, description: 'Variant prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Asset prefixed ID'

      response '204', 'variant asset deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:variant_id) { variant.prefixed_id }
        let(:id) { variant_image.prefixed_id }

        run_test!
      end
    end
  end
end
