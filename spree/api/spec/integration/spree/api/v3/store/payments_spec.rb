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

      sdk_example <<~JS
        const payments = await client.orders.payments.list('or_abc123', {
          bearerToken: '<token>',
        })
      JS

      response '200', 'payments found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Payment' }
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

    post 'Create payment' do
      let(:check_method) { create(:check_payment_method, stores: [store]) }

      tags 'Checkout'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a payment for a non-session payment method (e.g. Check, Cash on Delivery, Bank Transfer). For payment methods that require a session (e.g. Stripe, PayPal), use the payment sessions endpoint instead.'

      sdk_example <<~JS
        const payment = await client.orders.payments.create('or_abc123', {
          payment_method_id: 'pm_abc123',
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-order-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          payment_method_id: { type: :string, example: 'pm_abc123', description: 'Payment method ID (must be a non-session payment method)' },
          amount: { type: :string, example: '99.99', description: 'Payment amount (defaults to order total minus store credits)' },
          metadata: { type: :object, description: 'Arbitrary metadata to attach to the payment (write-only, not returned in Store API responses)' }
        },
        required: %w[payment_method_id]
      }

      response '201', 'payment created' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { payment_method_id: check_method.prefixed_id } }

        schema '$ref' => '#/components/schemas/Payment'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['state']).to eq('checkout')
          expect(data['payment_method_id']).to eq(check_method.prefixed_id)
        end
      end

      response '422', 'session-based payment method' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { payment_method_id: payment_method.prefixed_id } }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { 'invalid' }
        let(:body) { { payment_method_id: check_method.prefixed_id } }

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

      sdk_example <<~JS
        const payment = await client.orders.payments.get('or_abc123', 'pay_abc123', {
          bearerToken: '<token>',
        })
      JS

      response '200', 'payment found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { payment.to_param }

        schema '$ref' => '#/components/schemas/Payment'

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
