# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Payments API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user) }
  let!(:order) { create(:order_with_line_items, store: store, user: user, state: 'payment') }
  let!(:payment_method) { create(:credit_card_payment_method, stores: [store]) }
  let!(:payment) { create(:payment, order: order, payment_method: payment_method) }

  path '/api/v3/store/orders/{order_id}/payments' do
    get 'List payments for an order' do
      tags 'Payments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all payments associated with the order'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false

      response '200', 'payments found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.number }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StorePayment' } }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a payment' do
      tags 'Payments'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new payment for the order using the specified payment method'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          payment_method_id: { type: :string, description: 'Payment method ID' },
          amount: { type: :number, description: 'Payment amount (optional, defaults to order total)' },
          source_attributes: {
            type: :object,
            description: 'Payment source details (card info, etc.)',
            properties: {
              number: { type: :string },
              month: { type: :string },
              year: { type: :string },
              verification_value: { type: :string },
              name: { type: :string }
            }
          }
        },
        required: %w[payment_method_id]
      }

      response '201', 'payment created' do
        let(:check_payment_method) { create(:check_payment_method, stores: [store]) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.number }
        let(:body) do
          {
            payment_method_id: check_payment_method.id.to_s
          }
        end

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test!
      end

      response '422', 'invalid payment method' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.number }
        let(:body) { { payment_method_id: 'invalid' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/payments/{id}' do
    get 'Get a payment' do
      tags 'Payments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns details of a specific payment'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Payment ID'
      parameter name: :order_token, in: :query, type: :string, required: false

      response '200', 'payment found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.number }
        let(:id) { payment.prefix_id }

        schema '$ref' => '#/components/schemas/StorePayment'

        run_test!
      end

      response '404', 'payment not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.number }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
