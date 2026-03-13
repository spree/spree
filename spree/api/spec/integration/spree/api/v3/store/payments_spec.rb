# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Payments API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user, state: 'payment') }
  let(:cart_id) { order.prefixed_id }

  path '/api/v3/store/carts/{cart_id}/payments' do
    get 'List payments' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all payments for the cart.'

      sdk_example <<~JS
        const payments = await client.carts.payments.list('cart_abc123', {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID (e.g., cart_abc123)'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false

      response '200', 'payments listed' do
        let!(:payment) do
          pm = create(:check_payment_method, stores: [store])
          create(:payment, order: order, payment_method: pm, amount: order.total, state: 'checkout')
        end
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to eq(1)
          expect(data['data'][0]['id']).to eq(payment.prefixed_id)
          expect(data['meta']['count']).to eq(1)
        end
      end
    end

    post 'Create payment' do
      let(:check_method) { create(:check_payment_method, stores: [store]) }

      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a payment for a non-session payment method (e.g. Check, Cash on Delivery, Bank Transfer). For payment methods that require a session (e.g. Stripe, PayPal), use the payment sessions endpoint instead.'

      sdk_example <<~JS
        const payment = await client.carts.payments.create('cart_abc123', {
          payment_method_id: 'pm_abc123',
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          payment_method_id: { type: :string, example: 'pm_abc123', description: 'Payment method ID (must be a non-session payment method)' },
          amount: { type: :string, example: '99.99', description: 'Payment amount (defaults to order total minus store credits)' },
          metadata: { type: :object, description: 'Arbitrary metadata to attach to the payment' }
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
        let(:credit_card_method) { create(:credit_card_payment_method, stores: [store]) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { payment_method_id: credit_card_method.prefixed_id } }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end
  end
end
