# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Products API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:product) { create(:product, stores: [store], status: 'active') }
  let!(:product2) { create(:product, stores: [store], status: 'active') }
  let!(:draft_product) { create(:product, stores: [store], status: 'draft') }
  let!(:other_store) { create(:store) }
  let!(:other_store_product) { create(:product, stores: [other_store]) }

  path '/api/v3/store/products' do
    get 'List products' do
      tags 'Products'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a paginated list of active products for the current store'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true,
                description: 'Publishable API key'
      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Number of items per page (default: 25, max: 100)'
      parameter name: 'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name containing string'
      parameter name: 'q[taxons_id_eq]', in: :query, type: :string, required: false,
                description: 'Filter by taxon ID'
      parameter name: :includes, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to include (variants, images, taxons, option_types)'

      response '200', 'products found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreProduct' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to eq(2)
          expect(data['meta']).to include('page', 'limit', 'count', 'pages')
        end
      end

      response '401', 'unauthorized - invalid or missing API key' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end
    end
  end

  path '/api/v3/store/products/{id}' do
    get 'Get a product' do
      tags 'Products'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single product by slug or prefix ID'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true,
                description: 'Publishable API key'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Product slug (e.g., ruby-on-rails-tote) or prefix ID (e.g., product_abc123)'
      parameter name: :includes, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to include'

      response '200', 'product found by slug' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { product.slug }

        schema '$ref' => '#/components/schemas/StoreProduct'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product.prefix_id)
          expect(data['name']).to eq(product.name)
          expect(data['slug']).to eq(product.slug)
        end
      end

      response '200', 'product found by prefix ID' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { product.prefix_id }

        schema '$ref' => '#/components/schemas/StoreProduct'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product.prefix_id)
        end
      end

      response '404', 'product not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { 'nonexistent-product' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('record_not_found')
        end
      end

      response '404', 'product from another store' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { other_store_product.slug }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'draft product not visible' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { draft_product.slug }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

    end
  end
end
