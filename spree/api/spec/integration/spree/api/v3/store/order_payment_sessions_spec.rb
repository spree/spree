# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Order Payment Sessions API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, payment_requested_at: Time.current, store: store, customer: user) }
  let(:payment_method) { create(:bogus_payment_method) }
  let!(:payment_session) do
    create(:bogus_payment_session,
           order: order,
           payment_method: payment_method,
           amount: order.total,
           external_data: { 'client_secret' => 'secret_123' })
  end
  let(:order_id) { order.prefixed_id }
  let(:'x-spree-api-key') { api_key.token }
  let(:'Authorization') { "Bearer #{jwt_token}" }

  path '/api/v3/store/orders/{order_id}/payment_sessions' do
    post 'Create payment session for a draft order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a payment session for a draft order the merchant raised for the customer, as the cart endpoint does at checkout. Delegates to the payment gateway to initialize a provider-specific session.'

      sdk_example 'orders/payment-sessions-create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Draft order prefixed ID (e.g., or_abc123)'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false,
                description: 'Unique key for request idempotency.'
      request_body_for

      response '201', 'payment session created' do
        let(:body) { { payment_method_id: payment_method.prefixed_id } }

        schema '$ref' => '#/components/schemas/PaymentSession'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('pending')
          expect(data['order_id']).to eq(order.prefixed_id)
        end
      end

      response '404', 'draft order not found' do
        let(:order_id) { 'or_nonexistent' }
        let(:body) { { payment_method_id: payment_method.prefixed_id } }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/payment_sessions/{id}' do
    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: 'Authorization', in: :header, type: :string, required: false,
              description: 'Bearer token for authenticated customers'
    parameter name: :order_id, in: :path, type: :string, required: true, description: 'Draft order prefixed ID'
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Payment session ID'
    parameter name: 'x-spree-token', in: :header, type: :string, required: false,
              description: 'Order token for guest access'

    get 'Get payment session for a draft order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single payment session of a draft order with its current status and provider data.'

      sdk_example 'orders/payment-sessions-get'

      response '200', 'payment session found' do
        let(:id) { payment_session.to_param }

        schema '$ref' => '#/components/schemas/PaymentSession'

        run_test! do |response|
          expect(JSON.parse(response.body)['id']).to eq(payment_session.prefixed_id)
        end
      end
    end

    patch 'Update payment session for a draft order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a payment session of a draft order. Delegates to the payment gateway to sync changes with the provider.'

      sdk_example 'orders/payment-sessions-update'

      request_body_for

      response '200', 'payment session updated' do
        let(:id) { payment_session.to_param }
        let(:body) { { amount: '50.00' } }

        schema '$ref' => '#/components/schemas/PaymentSession'

        run_test! do |response|
          expect(JSON.parse(response.body)['amount']).to eq('50.00')
        end
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/payment_sessions/{id}/complete' do
    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: 'Authorization', in: :header, type: :string, required: false,
              description: 'Bearer token for authenticated customers'
    parameter name: :order_id, in: :path, type: :string, required: true, description: 'Draft order prefixed ID'
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Payment session ID'
    parameter name: 'x-spree-token', in: :header, type: :string, required: false,
              description: 'Order token for guest access'

    patch 'Complete payment session for a draft order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Confirms a draft order’s payment with the provider. Place the order afterwards with `POST /orders/{id}/complete`; a gateway webhook may place it first.'

      sdk_example 'orders/payment-sessions-complete'

      request_body_for
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false,
                description: 'Unique key for request idempotency.'

      response '200', 'payment session completed' do
        let(:id) { payment_session.to_param }
        let(:body) { { session_result: 'success' } }

        schema '$ref' => '#/components/schemas/PaymentSession'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('completed')
        end
      end
    end
  end
end
