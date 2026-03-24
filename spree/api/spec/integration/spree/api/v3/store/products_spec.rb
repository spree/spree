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
    create(:product, stores: [store], status: 'active', taxons: [child_taxon],
           description: '<p>A <strong>comfortable</strong> cotton t-shirt.</p>').tap do |p|
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
        const products = await client.products.list({
          page: 1,
          limit: 25,
          sort: 'price',
          name_cont: 'shirt',
          price_gte: 20,
          price_lte: 100,
          with_option_value_ids: ['optval_abc', 'optval_def'],
          expand: ['variants', 'media'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true,
                description: 'Publishable API key'
      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number (default: 1)'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of items per page (default: 25, max: 100)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort order. Prefix with - for descending. Values: price, -price, best_selling, name, -name, -available_on, available_on'
      parameter name: 'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name containing string'
      parameter name: 'q[categories_id_eq]', in: :query, type: :string, required: false,
                description: 'Filter by category ID'
      parameter name: 'q[price_gte]', in: :query, type: :number, required: false,
                description: 'Filter by minimum price'
      parameter name: 'q[price_lte]', in: :query, type: :number, required: false,
                description: 'Filter by maximum price'
      parameter name: 'q[with_option_value_ids][]', in: :query, type: :string, required: false,
                description: 'Filter by option value prefix IDs (e.g., optval_abc). Pass multiple values for OR logic.'
      parameter name: 'q[in_stock]', in: :query, type: :boolean, required: false,
                description: 'Filter to only in-stock products'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (variants, media, categories, option_types)'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'products found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Product' } },
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
        const product = await client.products.get('spree-tote', {
          expand: ['variants', 'media'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true,
                description: 'Publishable API key'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Product slug (e.g., spree-tote) or prefix ID (e.g., product_abc123)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'product found by slug' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { product.slug }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product.prefixed_id)
          expect(data['name']).to eq(product.name)
          expect(data['slug']).to eq(product.slug)
          expect(data['description']).to eq('A comfortable cotton t-shirt.')
          expect(data['description_html']).to eq('<p>A <strong>comfortable</strong> cotton t-shirt.</p>')
        end
      end

      response '200', 'product found by prefix ID' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { product.to_param }

        schema '$ref' => '#/components/schemas/Product'

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

      response '200', 'product with prior_price expanded' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { product.slug }
        let(:expand) { 'prior_price' }

        before do
          # Set up price history on all variant prices to ensure the
          # default_variant's price has history regardless of which variant is selected
          product.variants_including_master.each do |v|
            v.prices.base_prices.each do |price|
              price.price_histories.delete_all
              create(:price_history, price: price, variant: v, amount: 25.0, currency: price.currency, recorded_at: 1.day.ago)
              create(:price_history, price: price, variant: v, amount: 9.99, currency: price.currency, recorded_at: 15.days.ago)
            end
          end
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          lowest = data['prior_price']
          expect(lowest).to be_present
          expect(lowest['amount']).to eq('9.99')
          expect(lowest['currency']).to eq('USD')
          expect(lowest['display_amount']).to be_present
          expect(lowest['amount_in_cents']).to eq(999)
          expect(lowest['recorded_at']).to be_present
        end
      end

      response '200', 'product without prior_price expanded does not include field' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { product.slug }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).not_to have_key('prior_price')
        end
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

        The filters are context-aware - when a category_id is provided, only filters
        relevant to products in that category are returned.
      DESC

      sdk_example <<~JS
        const filters = await client.products.filters({
          category_id: 'ctg_abc123',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true,
                description: 'Publishable API key'
      parameter name: :category_id, in: :query, type: :string, required: false,
                description: 'Scope filters to products in this category (prefix ID)'
      parameter name: 'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name containing string'

      response '200', 'filters retrieved successfully' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 filters: {
                   type: :array,
                   description: 'Available filters (price_range, availability, option, category)',
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
          expect(sort_ids).to include('manual', 'price', '-available_on')
        end
      end

      response '200', 'filters scoped to category' do
        let(:'x-spree-api-key') { api_key.token }
        let(:category_id) { taxon.prefixed_id }

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

          # Should include category filter with child categories
          category_filter = data['filters'].find { |f| f['type'] == 'category' }
          expect(category_filter).to be_present
          expect(category_filter['options'].map { |t| t['name'] }).to include('Shirts')
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
