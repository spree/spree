# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Fulfillments API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user, state: 'delivery') }
  let!(:fulfillment) { order.shipments.first }
  let(:cart_id) { order.prefixed_id }

  path '/api/v3/store/carts/{cart_id}/fulfillments/{id}' do
    patch 'Select delivery rate for fulfillment' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Selects a delivery rate for a specific fulfillment and auto-advances checkout.'

      sdk_example 'carts/fulfillments-update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Fulfillment ID'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false, description: 'Order token for guest access'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          selected_delivery_rate_id: { type: :string, example: 'dr_abc123', description: 'Delivery rate ID to select' }
        },
        required: %w[selected_delivery_rate_id]
      }

      response '200', 'delivery rate selected, returns updated cart' do
        let(:delivery_rate) { fulfillment.shipping_rates.first }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { fulfillment.to_param }
        let(:body) { { selected_delivery_rate_id: delivery_rate.to_param } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(order.number)
        end
      end

      response '404', 'delivery rate not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { fulfillment.to_param }
        let(:body) { { selected_delivery_rate_id: 'dr_invalid' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
