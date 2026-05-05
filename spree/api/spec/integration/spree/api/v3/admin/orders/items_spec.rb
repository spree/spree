# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Line Items API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, stores: [store]) }
  let!(:variant) { create(:variant, product: product) }
  let!(:order) { create(:order, store: store, state: 'cart') }
  let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 2) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/items' do
    let(:order_id) { order.prefixed_id }

    get 'List order items' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all line items for an order.'
      admin_scope :read, :orders

      admin_sdk_example <<~JS
        const { data: items } = await client.orders.items.list('or_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., variant, variant.product). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., quantity,price,total). id is always included.'

      response '200', 'items found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to eq(1)
        end
      end
    end

    post 'Add an item' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a new line item to the order.'
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        const item = await client.orders.items.create('or_UkLWZg9DAJ', {
          variant_id: 'variant_k5nR8xLq',
          quantity: 2,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[variant_id],
        properties: {
          variant_id: { type: :string, description: 'Prefixed variant ID' },
          quantity: { type: :integer, default: 1 }
        }
      }

      response '201', 'item added' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:new_variant) { create(:variant, product: create(:product, stores: [store])) }
        let(:body) { { variant_id: new_variant.prefixed_id, quantity: 3 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['quantity']).to eq(3)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/items/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { line_item.prefixed_id }

    get 'Show an item' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns details of a specific line item.'
      admin_scope :read, :orders

      admin_sdk_example <<~JS
        const item = await client.orders.items.get('or_UkLWZg9DAJ', 'li_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Item ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., variant, variant.product). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., quantity,price,total). id is always included.'

      response '200', 'item found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(line_item.prefixed_id)
        end
      end
    end

    patch 'Update an item' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates an order item quantity or metadata.'
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        const item = await client.orders.items.update('or_UkLWZg9DAJ', 'li_UkLWZg9DAJ', {
          quantity: 5,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Item ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          quantity: { type: :integer }
        }
      }

      response '200', 'item updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { quantity: 5 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['quantity']).to eq(5)
        end
      end
    end

    delete 'Remove an item' do
      tags 'Orders'
      security [api_key: [], bearer_auth: []]
      description 'Removes an item from the order.'
      admin_scope :write, :orders

      admin_sdk_example <<~JS
        await client.orders.items.delete('or_UkLWZg9DAJ', 'li_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Item ID'

      response '204', 'line item removed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
