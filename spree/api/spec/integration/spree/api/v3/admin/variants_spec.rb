# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Variants API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product) }
  let!(:variant) { create(:variant, product: product) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/products/{product_id}/variants' do
    get 'List product variants' do
      tags 'Variants'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of variants for a product, including the default variant.'
      admin_scope :read, :products

      admin_sdk_example 'variants/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., images, prices, stock_levels, option_values). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., sku,price,stock). id is always included.'
      filter_parameters_for

      response '200', 'variants found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a variant' do
      tags 'Variants'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new variant for a product. Supports nested prices and stock items.

        Option types and values are auto-created if they don't exist.
        Prices are upserted by currency. Stock items are upserted by stock location.
      DESC
      admin_scope :write, :products

      admin_sdk_example 'variants/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'
      request_body_for

      response '201', 'variant created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:body) { { sku: 'NEW-SKU-001', prices: [{ currency: 'USD', amount: '24.99' }], options: [{ name: 'Size', value: 'XL' }] } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['sku']).to eq('NEW-SKU-001')
        end
      end

      # Reusing an existing variant's SKU violates the uniqueness validation.
      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:body) { { sku: variant.sku, prices: [{ currency: 'USD', amount: '9.99' }] } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/products/{product_id}/variants/{id}' do
    get 'Get a variant' do
      tags 'Variants'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single variant by ID.'
      admin_scope :read, :products

      admin_sdk_example 'variants/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Variant ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., images, prices, stock_levels, option_values). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., sku,price,stock). id is always included.'

      response '200', 'variant found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:id) { variant.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(variant.prefixed_id)
        end
      end

      response '404', 'variant not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:id) { 'variant_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a variant' do
      tags 'Variants'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a variant. Only provided fields are updated.'
      admin_scope :write, :products

      admin_sdk_example 'variants/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Variant ID'
      request_body_for

      response '200', 'variant updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:id) { variant.prefixed_id }
        let(:body) { { sku: 'UPDATED-SKU' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['sku']).to eq('UPDATED-SKU')
        end
      end
    end

    delete 'Delete a variant' do
      tags 'Variants'
      security [api_key: [], bearer_auth: []]
      description 'Soft-deletes a variant.'
      admin_scope :write, :products

      admin_sdk_example 'variants/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Variant ID'

      response '204', 'variant deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:id) { variant.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/variants' do
    get 'List variants' do
      tags 'Variants'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns every variant in the store across all products, for pickers and stock views that are not tied to one product.'
      admin_scope :read, :products

      admin_sdk_example 'variants/list-all'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :order_id, in: :query, type: :string, required: false,
                description: 'A draft order to sell to: lists only what its buyer can be sold on its channel, priced in its market. Needs `read_orders`.'
      parameter name: :market_id, in: :query, type: :string, required: false,
                description: 'Prices in this market and lists only variants with a price in its currency.'
      parameter name: :channel_id, in: :query, type: :string, required: false,
                description: 'Lists only variants published on this channel. Defaults to the store default channel when another sales context parameter is given.'
      parameter name: :customer_id, in: :query, type: :string, required: false,
                description: "Narrows to the customer's catalogs and prices as they would pay. Needs `read_customers`."
      parameter name: :company_id, in: :query, type: :string, required: false,
                description: "Narrows to the company's catalogs and prices under its agreement. Needs `read_customers`."
      parameter name: :currency, in: :query, type: :string, required: false,
                description: "Currency to price in. With `market_id` it must be the market's currency."
      filter_parameters_for

      response '200', 'variants found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Variant')

        run_test! do |response|
          ids = JSON.parse(response.body)['data'].map { |record| record['id'] }
          expect(ids).to include(variant.prefixed_id)
        end
      end
    end
  end
end
