# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Categories API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:taxonomy) { create(:taxonomy, store: store) }
  let!(:root_taxon) { taxonomy.root }
  let!(:category) { create(:taxon, taxonomy: taxonomy, parent: root_taxon) }
  let!(:child_category) { create(:taxon, taxonomy: taxonomy, parent: category) }
  let!(:product) { create(:product, stores: [store], status: 'active', taxons: [category]) }
  let!(:other_store) { create(:store) }
  let!(:other_taxonomy) { create(:taxonomy, store: other_store) }
  let!(:other_category) { create(:taxon, taxonomy: other_taxonomy) }

  path '/api/v3/store/categories' do
    get 'List categories' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a paginated list of categories for the current store'

      sdk_example <<~JS
        const categories = await client.categories.list({
          page: 1,
          limit: 25,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: 'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'categories found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Category' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].size).to be >= 1
          # Should not include categories from other stores
          ids = data['data'].map { |t| t['id'] }
          expect(ids).not_to include(other_category.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/categories/{id}' do
    get 'Get a category' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single category by permalink or prefix ID'

      sdk_example <<~JS
        const category = await client.categories.get('categories/clothing/shirts', {
          expand: 'children',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Category permalink (e.g., categories/clothing/shirts) or prefix ID (e.g., txn_abc123)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Expand associations (children, parent, ancestors, metafields)'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'category found by permalink' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { category.permalink }

        schema '$ref' => '#/components/schemas/Category'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq(category.name)
        end
      end

      response '200', 'category found by prefix ID' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { category.to_param }

        schema '$ref' => '#/components/schemas/Category'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq(category.name)
        end
      end

      response '404', 'category not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { 'non-existent-permalink' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'category from other store not accessible' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { other_category.permalink }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:id) { category.permalink }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/categories/{category_id}/products' do
    get 'List products in a category' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a paginated list of products belonging to the specified category'

      sdk_example <<~JS
        const products = await client.categories.products.list('categories/clothing', {
          page: 1,
          limit: 25,
          sort: 'price',
          with_option_value_ids: ['optval_abc'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :category_id, in: :path, type: :string, required: true,
                description: 'Category permalink or prefix ID'
      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number (default: 1)'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of items per page (default: 25, max: 100)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort order. Prefix with - for descending. Values: price, -price, best_selling, name, -name, -available_on, available_on'
      parameter name: 'q[price_gte]', in: :query, type: :number, required: false,
                description: 'Filter by minimum price'
      parameter name: 'q[price_lte]', in: :query, type: :number, required: false,
                description: 'Filter by maximum price'
      parameter name: 'q[with_option_value_ids][]', in: :query, type: :string, required: false,
                description: 'Filter by option value prefix IDs'
      parameter name: 'q[in_stock]', in: :query, type: :boolean, required: false,
                description: 'Filter to only in-stock products'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'products found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:category_id) { category.to_param }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Product' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].size).to eq(1)
          expect(data['data'].first['id']).to eq(product.prefixed_id)
        end
      end

      response '404', 'category not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:category_id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:category_id) { category.to_param }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
