# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Payments API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, store: store, user: user, state: 'payment') }
  let(:order_id) { order.to_param }
  let(:payment_method) { create(:credit_card_payment_method, stores: [store]) }
  let!(:payment) { create(:payment, order: order, payment_method: payment_method, amount: order.total) }

  path '/api/v3/store/orders/{order_id}/payments' do
    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: 'Authorization', in: :header, type: :string, required: true
    parameter name: :order_id, in: :path, type: :string, description: 'Order prefix ID'

    get 'List payments' do
      tags 'Checkout'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a list of payments for the specified order'

      response '200', 'payments found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/StorePayment' }
                 },
                 meta: { type: :object }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].length).to eq(1)
          expect(data['data'].first['id']).to eq(payment.prefixed_id)
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/payments/{id}' do
    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: 'Authorization', in: :header, type: :string, required: true
    parameter name: :order_id, in: :path, type: :string, description: 'Order prefix ID'
    parameter name: :id, in: :path, type: :string, description: 'Payment ID'

    get 'Get payment' do
      tags 'Checkout'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single payment by ID'

      response '200', 'payment found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { payment.to_param }

        schema '$ref' => '#/components/schemas/StorePayment'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment.prefixed_id)
          expect(data['state']).to eq(payment.state)
        end
      end

      response '404', 'payment not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end
  end
end
