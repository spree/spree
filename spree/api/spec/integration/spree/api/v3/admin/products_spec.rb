# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Products API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, stores: [store]) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/products' do
    get 'List products' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of products for the current store.'
      admin_scope :read, :products

      admin_sdk_example <<~JS
        const { data: products } = await client.products.list({
          name_cont: 'shirt',
          status_eq: 'active',
          sort: '-created_at',
          limit: 25,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort field (e.g., name, -name, price, -price, best_selling)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., variants, media, option_types, categories). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price,status). id is always included.'
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
      tags 'Product Catalog'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new product. Supports nested variants with prices and option types.

        Option types and values are auto-created if they don't exist.
        Prices are upserted by currency. Stock items are upserted by stock location.
      DESC
      admin_scope :write, :products

      admin_sdk_example <<~JS
        const product = await client.products.create({
          name: 'Premium T-Shirt',
          price: 29.99,
          description: 'Soft, organic cotton.',
          status: 'active',
          variants: [
            {
              sku: 'TSHIRT-S-NAVY',
              options: [
                { name: 'size', value: 'Small' },
                { name: 'color', value: 'navy' },
              ],
              prices: [
                { currency: 'USD', amount: 29.99 },
                { currency: 'EUR', amount: 27.99 },
              ],
              stock_items: [
                { stock_location_id: 'sloc_UkLWZg9DAJ', count_on_hand: 50 },
              ],
            },
            {
              sku: 'TSHIRT-M-NAVY',
              options: [
                { name: 'size', value: 'Medium' },
                { name: 'color', value: 'navy' },
              ],
              prices: [{ currency: 'USD', amount: 29.99 }],
              stock_items: [
                { stock_location_id: 'sloc_UkLWZg9DAJ', count_on_hand: 30 },
              ],
            },
          ],
        })
      JS

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
          tax_category_id: { type: :string, description: 'Tax category ID' },
          category_ids: { type: :array, items: { type: :string }, description: 'Array of category IDs' },
          tags: { type: :array, items: { type: :string }, example: %w[eco sale] },
          variants: {
            type: :array,
            description: 'Array of variant payloads. Variants can declare multiple option pairs via `options:` and per-currency prices via `prices:`. Stock counts go in `stock_items:` (per stock location).',
            items: {
              type: :object,
              properties: {
                sku: { type: :string },
                options: {
                  type: :array,
                  description: 'One pair per option type the variant participates in (e.g. size + color). Option types and values are auto-created if missing.',
                  items: {
                    type: :object,
                    required: %w[name value],
                    properties: {
                      name: { type: :string, example: 'size' },
                      value: { type: :string, example: 'Small' }
                    }
                  }
                },
                prices: {
                  type: :array,
                  description: 'Per-currency prices. Upserted by currency.',
                  items: {
                    type: :object,
                    required: %w[currency amount],
                    properties: {
                      currency: { type: :string, example: 'USD' },
                      amount: { type: :number, example: 29.99 },
                      compare_at_amount: { type: :number, example: 39.99 }
                    }
                  }
                },
                stock_items: {
                  type: :array,
                  description: 'Per-stock-location inventory. Upserted by stock_location_id.',
                  items: {
                    type: :object,
                    required: %w[stock_location_id count_on_hand],
                    properties: {
                      stock_location_id: { type: :string, description: 'Stock location ID (e.g. sloc_xxx)' },
                      count_on_hand: { type: :integer, example: 50 },
                      backorderable: { type: :boolean }
                    }
                  }
                }
              }
            }
          }
        },
        required: %w[name price]
      }

      response '201', 'product created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'New Product', price: 19.99 } }

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
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single product by ID.'
      admin_scope :read, :products

      admin_sdk_example <<~JS
        const product = await client.products.get('prod_86Rf07xd4z', {
          expand: ['variants', 'option_types'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product ID (e.g., prod_xxx)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., variants, media, option_types, categories). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price,status). id is always included.'

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
      tags 'Product Catalog'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a product. Only provided fields are updated.'
      admin_scope :write, :products

      admin_sdk_example <<~JS
        const product = await client.products.update('prod_86Rf07xd4z', {
          name: 'Updated Name',
          status: 'active',
          tags: ['eco', 'sale'],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Premium T-Shirt' },
          price: { type: :number, example: 29.99 },
          description: { type: :string },
          slug: { type: :string },
          status: { type: :string, enum: %w[draft active archived] },
          sku: { type: :string },
          tax_category_id: { type: :string, description: 'Tax category ID' },
          category_ids: { type: :array, items: { type: :string }, description: 'Array of category IDs' },
          tags: { type: :array, items: { type: :string }, example: %w[eco sale] },
          variants: {
            type: :array,
            description: 'Array of variant payloads. Variants can declare multiple option pairs via `options:` and per-currency prices via `prices:`. Stock counts go in `stock_items:` (per stock location).',
            items: {
              type: :object,
              properties: {
                sku: { type: :string },
                options: {
                  type: :array,
                  description: 'One pair per option type the variant participates in (e.g. size + color). Option types and values are auto-created if missing.',
                  items: {
                    type: :object,
                    required: %w[name value],
                    properties: {
                      name: { type: :string, example: 'size' },
                      value: { type: :string, example: 'Small' }
                    }
                  }
                },
                prices: {
                  type: :array,
                  description: 'Per-currency prices. Upserted by currency.',
                  items: {
                    type: :object,
                    required: %w[currency amount],
                    properties: {
                      currency: { type: :string, example: 'USD' },
                      amount: { type: :number, example: 29.99 },
                      compare_at_amount: { type: :number, example: 39.99 }
                    }
                  }
                },
                stock_items: {
                  type: :array,
                  description: 'Per-stock-location inventory. Upserted by stock_location_id.',
                  items: {
                    type: :object,
                    required: %w[stock_location_id count_on_hand],
                    properties: {
                      stock_location_id: { type: :string, description: 'Stock location ID (e.g. sloc_xxx)' },
                      count_on_hand: { type: :integer, example: 50 },
                      backorderable: { type: :boolean }
                    }
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
      tags 'Product Catalog'
      security [api_key: [], bearer_auth: []]
      description 'Soft-deletes a product.'
      admin_scope :write, :products

      admin_sdk_example <<~JS
        await client.products.delete('prod_86Rf07xd4z')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product ID'

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
