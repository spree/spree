# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Variants API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, stores: [store]) }
  let!(:variant) { create(:variant, product: product) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/products/{product_id}/variants' do
    get 'List product variants' do
      tags 'Variants'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of variants for a product, including the master variant.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., images, prices, stock_items)'

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

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          sku: { type: :string, example: 'SKU-001' },
          price: { type: :number, example: 29.99 },
          compare_at_price: { type: :number, example: 39.99 },
          cost_price: { type: :number, example: 10.0 },
          cost_currency: { type: :string, example: 'USD' },
          weight: { type: :number },
          height: { type: :number },
          width: { type: :number },
          depth: { type: :number },
          weight_unit: { type: :string },
          dimensions_unit: { type: :string },
          track_inventory: { type: :boolean },
          tax_category_id: { type: :string },
          options: {
            type: :array,
            description: 'Option types and values (auto-created if needed)',
            items: {
              type: :object,
              properties: {
                name: { type: :string, example: 'Size' },
                value: { type: :string, example: 'Large' }
              },
              required: %w[name value]
            }
          },
          total_on_hand: { type: :integer, example: 100 },
          position: { type: :integer },
          barcode: { type: :string },
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
          },
          stock_items: {
            type: :array,
            items: {
              type: :object,
              properties: {
                stock_location_id: { type: :string },
                count_on_hand: { type: :integer },
                backorderable: { type: :boolean }
              }
            }
          }
        }
      }

      response '201', 'variant created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:body) { { sku: 'NEW-SKU-001', price: 24.99, options: [{ name: 'Size', value: 'XL' }] } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['sku']).to eq('NEW-SKU-001')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:body) { { sku: '' } }

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
      description 'Returns a single variant by prefixed ID.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Variant prefixed ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., images, prices, stock_items)'

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

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Variant prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          sku: { type: :string, example: 'SKU-001' },
          price: { type: :number, example: 29.99 },
          compare_at_price: { type: :number, example: 39.99 },
          cost_price: { type: :number, example: 10.0 },
          cost_currency: { type: :string, example: 'USD' },
          weight: { type: :number },
          height: { type: :number },
          width: { type: :number },
          depth: { type: :number },
          weight_unit: { type: :string },
          dimensions_unit: { type: :string },
          track_inventory: { type: :boolean },
          tax_category_id: { type: :string },
          options: {
            type: :array,
            items: {
              type: :object,
              properties: {
                name: { type: :string, example: 'Size' },
                value: { type: :string, example: 'Large' }
              }
            }
          },
          total_on_hand: { type: :integer, example: 100 },
          position: { type: :integer },
          barcode: { type: :string },
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
          },
          stock_items: {
            type: :array,
            items: {
              type: :object,
              properties: {
                stock_location_id: { type: :string },
                count_on_hand: { type: :integer },
                backorderable: { type: :boolean }
              }
            }
          }
        }
      }

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

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Variant prefixed ID'

      response '204', 'variant deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:id) { variant.prefixed_id }

        run_test!
      end
    end
  end
end
