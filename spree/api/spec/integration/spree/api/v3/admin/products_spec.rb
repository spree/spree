# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Products API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, stores: [store]) }
  let(:shipping_category) { create(:shipping_category) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/products' do
    get 'List products' do
      tags 'Products'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of products for the current store.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort field (e.g., name, -name, price, -price, best_selling)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., variants, variants.images)'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :'q[status_eq]', in: :query, type: :string, required: false,
                description: 'Filter by status'

      response '200', 'products found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Product')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['meta']).to include('page', 'limit', 'count', 'pages')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a product' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new product. Supports nested variants with prices and option types.

        Option types and values are auto-created if they don't exist.
        Prices are upserted by currency. Stock items are upserted by stock location.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Premium T-Shirt' },
          price: { type: :number, example: 29.99 },
          description: { type: :string },
          slug: { type: :string },
          status: { type: :string, enum: %w[draft active archived] },
          sku: { type: :string },
          shipping_category_id: { type: :string, description: 'Prefixed ID (e.g., sc_xxx) or integer' },
          tax_category_id: { type: :string, description: 'Prefixed ID or integer' },
          taxon_ids: { type: :array, items: { type: :string }, description: 'Array of prefixed taxon IDs' },
          tags: { type: :array, items: { type: :string }, example: %w[eco sale] },
          variants: {
            type: :array,
            items: {
              type: :object,
              properties: {
                sku: { type: :string },
                price: { type: :number },
                option_type: { type: :string, example: 'Size' },
                option_value: { type: :string, example: 'Small' },
                total_on_hand: { type: :integer },
                prices: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      currency: { type: :string, example: 'USD' },
                      amount: { type: :number, example: 29.99 },
                      compare_at_amount: { type: :number, example: 39.99 }
                    },
                    required: %w[currency amount]
                  }
                }
              }
            }
          }
        },
        required: %w[name price shipping_category_id]
      }

      response '201', 'product created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'New Product', price: 19.99, shipping_category_id: shipping_category.id } }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('New Product')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/products/{id}' do
    get 'Get a product' do
      tags 'Products'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single product by prefixed ID.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product prefixed ID (e.g., prod_xxx)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., variants)'

      response '200', 'product found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { product.prefixed_id }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product.prefixed_id)
        end
      end

      response '404', 'product not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'prod_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a product' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a product. Only provided fields are updated.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Premium T-Shirt' },
          price: { type: :number, example: 29.99 },
          description: { type: :string },
          slug: { type: :string },
          status: { type: :string, enum: %w[draft active archived] },
          sku: { type: :string },
          shipping_category_id: { type: :string, description: 'Prefixed ID (e.g., sc_xxx) or integer' },
          tax_category_id: { type: :string, description: 'Prefixed ID or integer' },
          taxon_ids: { type: :array, items: { type: :string }, description: 'Array of prefixed taxon IDs' },
          tags: { type: :array, items: { type: :string }, example: %w[eco sale] },
          variants: {
            type: :array,
            items: {
              type: :object,
              properties: {
                sku: { type: :string },
                price: { type: :number },
                option_type: { type: :string, example: 'Size' },
                option_value: { type: :string, example: 'Small' },
                total_on_hand: { type: :integer },
                prices: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      currency: { type: :string, example: 'USD' },
                      amount: { type: :number, example: 29.99 },
                      compare_at_amount: { type: :number, example: 39.99 }
                    },
                    required: %w[currency amount]
                  }
                }
              }
            }
          }
        }
      }

      response '200', 'product updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { product.prefixed_id }
        let(:body) { { name: 'Updated Name' } }

        schema '$ref' => '#/components/schemas/Product'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Updated Name')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { product.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a product' do
      tags 'Products'
      security [api_key: [], bearer_auth: []]
      description 'Soft-deletes a product.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product prefixed ID'

      response '204', 'product deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { product.prefixed_id }

        run_test! do
          expect(product.reload.deleted_at).not_to be_nil
        end
      end
    end
  end
end
