# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Shipments API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user, state: 'delivery') }
  let!(:shipment) { order.shipments.first }

  path '/api/v3/store/orders/{order_id}/shipments' do
    get 'List shipments for an order' do
      tags 'Shipments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all shipments associated with the order'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :token, in: :query, type: :string, required: false, description: 'Order token for guest access'

      response '200', 'shipments found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreShipment' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].size).to be >= 1
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { 'R999999999' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/shipments/{id}' do
    get 'Get a shipment' do
      tags 'Shipments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns details of a specific shipment'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Shipment ID'
      parameter name: :token, in: :query, type: :string, required: false, description: 'Order token for guest access'
      parameter name: :includes, in: :query, type: :string, required: false,
                description: 'Include shipping_rates'

      response '200', 'shipment found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:id) { shipment.to_param }
        let(:token) { order.token }

        schema '$ref' => '#/components/schemas/StoreShipment'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to eq(shipment.number)
        end
      end

      response '404', 'shipment not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:id) { 'shp_nonexistent' }
        let(:token) { order.token }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Select shipping rate for shipment' do
      tags 'Shipments'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Selects a shipping rate for the shipment'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Shipment ID'
      parameter name: :token, in: :query, type: :string, required: false, description: 'Order token for guest access'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          selected_shipping_rate_id: { type: :string, example: 'shprt_abc123', description: 'Shipping rate ID to select' }
        },
        required: %w[selected_shipping_rate_id]
      }

      response '200', 'shipping rate selected, returns updated order' do
        let(:shipping_rate) { shipment.shipping_rates.first }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:id) { shipment.to_param }
        let(:token) { order.token }
        let(:body) { { selected_shipping_rate_id: shipping_rate.to_param } }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to eq(order.number)
        end
      end

      response '404', 'shipping rate not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:id) { shipment.to_param }
        let(:token) { order.token }
        let(:body) { { selected_shipping_rate_id: 'shprt_invalid' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
