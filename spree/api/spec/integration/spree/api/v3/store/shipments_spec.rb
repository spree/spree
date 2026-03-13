# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Shipments API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user, state: 'delivery') }
  let!(:shipment) { order.shipments.first }
  let(:cart_id) { order.prefixed_id }

  path '/api/v3/store/carts/{cart_id}/shipments' do
    get 'List shipments' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all shipments with shipping rates for the cart.'

      sdk_example <<~JS
        const shipments = await client.carts.shipments.list('cart_abc123', {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID (e.g., cart_abc123)'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false, description: 'Order token for guest access'

      response '200', 'shipments found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].size).to be >= 1
        end
      end
    end
  end

  path '/api/v3/store/carts/{cart_id}/shipments/{id}' do
    patch 'Select shipping rate for shipment' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Selects a shipping rate for a specific shipment and auto-advances checkout.'

      sdk_example <<~JS
        const cart = await client.carts.shipments.update('cart_abc123', 'ship_abc123', {
          selected_shipping_rate_id: 'shpr_abc123',
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Shipment ID'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false, description: 'Order token for guest access'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          selected_shipping_rate_id: { type: :string, example: 'shpr_abc123', description: 'Shipping rate ID to select' }
        },
        required: %w[selected_shipping_rate_id]
      }

      response '200', 'shipping rate selected, returns updated cart' do
        let(:shipping_rate) { shipment.shipping_rates.first }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { shipment.to_param }
        let(:body) { { selected_shipping_rate_id: shipping_rate.to_param } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(order.number)
        end
      end

      response '404', 'shipping rate not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { shipment.to_param }
        let(:body) { { selected_shipping_rate_id: 'shpr_invalid' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
