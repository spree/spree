# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Order Exchanges API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:order) { create(:shipped_order, store: store, customer: user) }
  let!(:exchange) { create(:exchange, order: order) }

  path '/api/v3/store/orders/{order_id}/exchanges' do
    parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'

    get 'List exchanges' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The exchanges opened on one of the customer\'s orders, newest first. Accessible via JWT or the order token header for guests.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      filter_parameters_for

      response '200', 'exchanges listed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:Authorization) { "Bearer #{jwt_token}" }
        let(:order_id) { order.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('Exchange')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].pluck('id')).to eq([exchange.prefixed_id])
        end
      end
    end

    post 'Open an exchange' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Swaps shipped units of one of the customer\'s orders for another purchasable variant of the same product — ' \
                  'a different size or colour. Approving, receiving and sending the replacement are the merchant\'s. ' \
                  'Accessible via JWT or the order token header for guests.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      request_body_for

      let(:'x-spree-api-key') { api_key.token }
      let(:Authorization) { "Bearer #{jwt_token}" }
      let(:exchangeable_order) { create(:shipped_order, store: store, customer: user) }
      let(:unit) { exchangeable_order.fulfillment_items.first }
      let(:order_id) { exchangeable_order.prefixed_id }

      response '201', 'exchange opened' do
        let(:replacement) { create(:variant, product: unit.variant.product) }
        let(:body) do
          { items: [{ fulfillment_item_id: unit.prefixed_id, new_variant_id: replacement.prefixed_id, quantity: 1 }], memo: 'Too small' }
        end

        schema '$ref' => '#/components/schemas/Exchange'

        run_test! do |response|
          expect(JSON.parse(response.body)).to include('status' => 'requested', 'cancelable' => true)
        end
      end

      response '422', 'the replacement is not a variant of the same product' do
        let(:body) do
          { items: [{ fulfillment_item_id: unit.prefixed_id, new_variant_id: create(:variant).prefixed_id, quantity: 1 }] }
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          expect(response.body).to include('another available variant of the same product')
          expect(exchangeable_order.reload.exchanges).to be_empty
        end
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/exchanges/{id}/cancel' do
    parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
    parameter name: :id, in: :path, type: :string, required: true, description: 'Exchange prefixed ID'

    patch 'Withdraw an exchange request' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Withdraws an exchange the customer opened, while the merchant has not acted on it yet (`cancelable` on the exchange). ' \
                  'Accessible via JWT or the order token header for guests.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'

      response '200', 'exchange withdrawn' do
        let(:'x-spree-api-key') { api_key.token }
        let(:Authorization) { "Bearer #{jwt_token}" }
        let(:order_id) { order.prefixed_id }
        let(:id) { exchange.prefixed_id }

        schema '$ref' => '#/components/schemas/Exchange'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('canceled')
        end
      end
    end
  end
end
