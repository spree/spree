# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Fulfillments API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:shipment) { order.shipments.first }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/fulfillments' do
    let(:order_id) { order.prefixed_id }

    get 'List fulfillments' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all shipments for an order.'
      admin_scope :read, :fulfillments

      admin_sdk_example <<~JS
        const { data: fulfillments } = await client.orders.fulfillments.list('or_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., inventory_units, stock_location, shipping_rates). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., number,status,tracking,cost). id is always included.'

      response '200', 'fulfillments found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to eq(1)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { shipment.prefixed_id }

    get 'Show a shipment' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns details of a specific shipment.'
      admin_scope :read, :fulfillments

      admin_sdk_example <<~JS
        const fulfillment = await client.orders.fulfillments.get('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., inventory_units, stock_location, shipping_rates). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., number,status,tracking,cost). id is always included.'

      response '200', 'shipment found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(shipment.prefixed_id)
          expect(data['number']).to be_present
        end
      end
    end

    patch 'Update a shipment' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a shipment (tracking, shipping rate).'
      admin_scope :write, :fulfillments

      admin_sdk_example <<~JS
        const fulfillment = await client.orders.fulfillments.update('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ', {
          tracking: '1Z999AA10123456784',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          tracking: { type: :string, example: '1Z999AA10123456784' },
          selected_shipping_rate_id: { type: :string }
        }
      }

      response '200', 'shipment updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { tracking: '1Z999AA10123456784' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tracking']).to eq('1Z999AA10123456784')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}/fulfill' do
    patch 'Fulfill a fulfillment' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Marks a fulfillment as fulfilled.'
      admin_scope :write, :fulfillments

      admin_sdk_example <<~JS
        const fulfillment = await client.orders.fulfillments.fulfill('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'

      response '200', 'fulfillment fulfilled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { shipment.prefixed_id }

        before do
          shipment.ready! if shipment.can_ready?
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('shipped')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}/cancel' do
    patch 'Cancel a fulfillment' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Cancels a fulfillment.'
      admin_scope :write, :fulfillments

      admin_sdk_example <<~JS
        const fulfillment = await client.orders.fulfillments.cancel('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'

      response '200', 'fulfillment canceled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { shipment.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('canceled')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}/resume' do
    patch 'Resume a fulfillment' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Resumes a canceled fulfillment.'
      admin_scope :write, :fulfillments

      admin_sdk_example <<~JS
        const fulfillment = await client.orders.fulfillments.resume('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'

      response '200', 'fulfillment resumed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { shipment.prefixed_id }

        before do
          shipment.cancel!
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(%w[pending ready]).to include(data['status'])
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}/split' do
    patch 'Split a fulfillment' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Transfers items from this shipment to a new shipment at a different stock location.'
      admin_scope :write, :fulfillments

      admin_sdk_example <<~JS
        const fulfillment = await client.orders.fulfillments.split('or_UkLWZg9DAJ', 'ful_UkLWZg9DAJ', {
          quantity: 1,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[variant_id quantity],
        properties: {
          variant_id: { type: :string, description: 'Variant ID' },
          quantity: { type: :integer, example: 1 },
          stock_location_id: { type: :string, description: 'Target stock location ID' }
        }
      }

      response '200', 'fulfillment split' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { shipment.prefixed_id }
        let(:variant) { shipment.inventory_units.first.variant }
        let(:stock_location) { create(:stock_location, name: 'Warehouse 2') }
        let(:body) { { variant_id: variant.prefixed_id, quantity: 1, stock_location_id: stock_location.prefixed_id } }

        before do
          stock_location.stock_items.find_or_create_by(variant: variant).set_count_on_hand(10)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end
end
