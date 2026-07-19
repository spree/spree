# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Collections API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:collection) { create(:collection, store: store, name: 'Summer Sale') }
  let!(:product) { create(:product, status: 'active', stores: [store]) }
  let!(:other_store) { create(:store) }
  let!(:other_collection) { create(:collection, store: other_store) }

  before { Spree::ProductCollection.create!(collection: collection, product: product, position: 1) }

  path '/api/v3/store/collections' do
    get 'List collections' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a paginated list of collections for the current store.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: 'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,permalink). id is always included.'

      response '200', 'collections found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Collection' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          ids = data['data'].map { |c| c['id'] }
          expect(ids).to include(collection.prefixed_id)
          # Collections from other stores must not leak.
          expect(ids).not_to include(other_collection.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/collections/{id}' do
    get 'Get a collection' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single collection by permalink or prefix ID.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Collection permalink (e.g., summer-sale) or prefix ID (e.g., coll_abc123)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Expand associations (custom_fields)'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'collection found by permalink' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { collection.permalink }

        schema '$ref' => '#/components/schemas/Collection'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq(collection.name)
        end
      end

      response '200', 'collection found by prefix ID' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { collection.to_param }

        schema '$ref' => '#/components/schemas/Collection'

        run_test!
      end

      response '404', 'collection not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { 'non-existent-permalink' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'collection from other store not accessible' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { other_collection.permalink }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/collections/{collection_id}/products' do
    get 'List collection products' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Products in the collection. Defaults to the collection\'s own sort order and accepts the same filters, sort, and pagination as the products endpoint.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :collection_id, in: :path, type: :string, required: true,
                description: 'Collection permalink or prefix ID'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort order (e.g., price, -price). Defaults to the collection\'s sort_order.'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false

      response '200', 'products found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:collection_id) { collection.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Product' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end
end
