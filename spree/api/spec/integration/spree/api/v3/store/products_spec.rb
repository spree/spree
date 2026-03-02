# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Products API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:taxon) { create(:taxon, taxonomy: taxonomy) }
  let(:child_taxon) { create(:taxon, taxonomy: taxonomy, parent: taxon, name: 'Shirts') }

  let(:option_type) { create(:option_type, name: 'size', presentation: 'Size', filterable: true) }
  let(:option_value_small) { create(:option_value, option_type: option_type, name: 'small', presentation: 'S') }

  let!(:product) do
    create(:product, stores: [store], status: 'active', taxons: [child_taxon]).tap do |p|
      p.option_types << option_type
      create(:variant, product: p, option_values: [option_value_small])
    end
  end
  let!(:product2) { create(:product, stores: [store], status: 'active', taxons: [child_taxon]) }
  let!(:draft_product) { create(:product, stores: [store], status: 'draft') }
  let!(:other_store) { create(:store) }
  let!(:other_store_product) { create(:product, stores: [other_store]) }

  path '/api/v3/store/products' do
    get 'List products' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a paginated list of active products for the current store'

      sdk_example <<~JS
        const products = await client.store.products.list({
          page: 1,
          per_page: 25,
          sort: 'price asc',
          name_cont: 'shirt',
          price_gte: 20,
          price_lte: 100,
          with_option_value_ids: ['optval_abc', 'optval_def'],
          includes: ['variants', 'images'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true,
                description: 'Publishable API key'
      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Number of items per page (default: 25, max: 100)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort order. Values: price asc, price desc, best_selling, name asc, name desc, available_on desc, available_on asc'
      parameter name: 'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name containing string'
      parameter name: 'q[taxons_id_eq]', in: :query, type: :string, required: false,
                description: 'Filter by taxon ID'
      parameter name: 'q[price_gte]', in: :query, type: :number, required: false,
                description: 'Filter by minimum price'
      parameter name: 'q[price_lte]', in: :query, type: :number, required: false,
                description: 'Filter by maximum price'
      parameter name: 'q[with_option_value_ids][]', in: :query, type: :string, required: false,
                description: 'Filter by option value prefix IDs (e.g., optval_abc). Pass multiple values for OR logic.'
      parameter name: 'q[in_stock]', in: :query, type: :boolean, required: false,
                description: 'Filter to only in-stock products'
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
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single product by slug or prefix ID'

      sdk_example <<~JS
        const product = await client.store.products.get('spree-tote', {
          includes: ['variants', 'images'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true,
                description: 'Publishable API key'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Product slug (e.g., spree-tote) or prefix ID (e.g., product_abc123)'
      parameter name: :includes, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to include'

      response '200', 'product found by slug' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { product.slug }

        schema '$ref' => '#/components/schemas/StoreProduct'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product.prefixed_id)
          expect(data['name']).to eq(product.name)
          expect(data['slug']).to eq(product.slug)
        end
      end

      response '200', 'product found by prefix ID' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { product.to_param }

        schema '$ref' => '#/components/schemas/StoreProduct'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product.prefixed_id)
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

  path '/api/v3/store/products/filters' do
    get 'Get product filters' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Returns available filters for products with their options and counts.
        Use this endpoint to build filter UIs for product listing pages.

        The filters are context-aware - when a taxon_id is provided, only filters
        relevant to products in that taxon are returned.
      DESC

      sdk_example <<~JS
        const filters = await client.store.products.filters({
          taxon_id: 'taxon_abc123',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true,
                description: 'Publishable API key'
      parameter name: :taxon_id, in: :query, type: :string, required: false,
                description: 'Scope filters to products in this taxon (prefix ID)'
      parameter name: 'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name containing string'

      response '200', 'filters retrieved successfully' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 filters: {
                   type: :array,
                   description: 'Available filters (price_range, availability, option, taxon)',
                   items: { type: :object }
                 },
                 sort_options: {
                   type: :array,
                   description: 'Available sort options',
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string }
                     },
                     required: %w[id]
                   }
                 },
                 default_sort: {
                   type: :string,
                   description: 'Default sort option ID'
                 },
                 total_count: {
                   type: :integer,
                   description: 'Total products matching current filters'
                 }
               },
               required: %w[filters sort_options default_sort total_count]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to have_key('filters')
          expect(data).to have_key('sort_options')
          expect(data).to have_key('default_sort')
          expect(data).to have_key('total_count')
          expect(data['total_count']).to eq(2)

          # Check price filter
          price_filter = data['filters'].find { |f| f['type'] == 'price_range' }
          expect(price_filter).to be_present
          expect(price_filter).to include('min', 'max', 'currency')

          # Check availability filter
          availability_filter = data['filters'].find { |f| f['type'] == 'availability' }
          expect(availability_filter).to be_present

          # Check option filter
          size_filter = data['filters'].find { |f| f['name'] == 'size' }
          expect(size_filter).to be_present
          expect(size_filter['type']).to eq('option')

          # Check sort options
          sort_ids = data['sort_options'].map { |s| s['id'] }
          expect(sort_ids).to include('manual', 'price asc', 'available_on desc')
        end
      end

      response '200', 'filters scoped to taxon' do
        let(:'x-spree-api-key') { api_key.token }
        let(:taxon_id) { taxon.prefixed_id }

        schema type: :object,
               properties: {
                 filters: { type: :array, items: { type: :object } },
                 sort_options: { type: :array, items: { type: :object } },
                 default_sort: { type: :string },
                 total_count: { type: :integer }
               },
               required: %w[filters sort_options default_sort total_count]

        run_test! do |response|
          data = JSON.parse(response.body)

          # Should include taxon filter with child taxons
          taxon_filter = data['filters'].find { |f| f['type'] == 'taxon' }
          expect(taxon_filter).to be_present
          expect(taxon_filter['options'].map { |t| t['name'] }).to include('Shirts')
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
end
