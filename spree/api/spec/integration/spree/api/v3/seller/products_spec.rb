# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Products API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:product) { create(:product, store: store, seller: seller) }

  path '/api/v3/seller/products' do
    get 'List products' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The seller's own catalog — the products they own outright.

        Every call is rooted in the acting seller server-side, so this can never
        return another seller's product or one the marketplace operator sells
        first-party.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      parameter name: :sort, in: :query, type: :string, required: false, description: 'Sort field; prefix with `-` for descending'

      response '200', 'products listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Product' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(product.prefixed_id)
        end
      end
    end

    post 'Create a product' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Creates a product owned by the acting seller.

        The seller and the store are taken from the request context whatever the
        payload says, so a product cannot be created against another seller.

        The operator's own settings — tax category, delivery profile and whether
        the product is promotionable — are not writable here; they belong to the
        marketplace, not the seller.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Hand-thrown mug' },
          description: { type: :string },
          slug: { type: :string, example: 'hand-thrown-mug' },
          status: { type: :string, example: 'draft' },
          meta_title: { type: :string },
          meta_description: { type: :string },
          meta_keywords: { type: :string },
          product_type_id: { type: :string, example: 'ptype_abc123' },
          tags: { type: :array, items: { type: :string }, example: %w[ceramics handmade] },
          category_ids: { type: :array, items: { type: :string }, example: ['cat_abc123'] },
          metadata: { type: :object, additionalProperties: true },
          prices: {
            type: :array,
            items: {
              type: :object,
              properties: {
                amount: { type: :string, example: '24.00' },
                compare_at_amount: { type: :string, example: '30.00' },
                currency: { type: :string, example: 'USD' }
              }
            }
          }
        },
        required: %w[name]
      }

      response '201', 'product created' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: 'Hand-thrown mug', prices: [{ amount: '24.00', currency: 'USD' }] } }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Hand-thrown mug')
        end
      end

      response '422', 'validation failed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/products/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Product ID'

    get 'Get a product' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        A product the acting seller owns.

        An id belonging to another seller answers `404`, not `403` — the seller
        is not told the record exists.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'product returned' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product.prefixed_id }

        schema '$ref' => '#/components/schemas/Product'

        run_test!
      end

      response '404', "another seller's product" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:other_seller) { create(:seller, :approved, store: store) }
        let(:id) { create(:product, store: store, seller: other_seller).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a product' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Edits a product the acting seller owns.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Hand-thrown mug, large' },
          description: { type: :string },
          slug: { type: :string },
          status: { type: :string, example: 'active' },
          tags: { type: :array, items: { type: :string } },
          category_ids: { type: :array, items: { type: :string } },
          metadata: { type: :object, additionalProperties: true }
        }
      }

      response '200', 'product updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product.prefixed_id }
        let(:body) { { name: 'Hand-thrown mug, large' } }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Hand-thrown mug, large')
        end
      end
    end

    delete 'Delete a product' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Deletes a product the acting seller owns.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'product deleted' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product.prefixed_id }

        run_test!
      end
    end
  end
end
