# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Payment Sessions API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:order) { create(:order_with_line_items, store: store, user: user, state: 'payment') }
  let(:order_id) { order.to_param }
  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let!(:payment_session) do
    create(:bogus_payment_session,
           order: order,
           payment_method: payment_method,
           amount: order.total,
           external_data: { 'client_secret' => 'secret_123' })
  end

  path '/api/v3/store/orders/{order_id}/payment_sessions' do
    post 'Create payment session' do
      tags 'Checkout'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new payment session for the specified order. Delegates to the payment gateway to initialize a provider-specific session (e.g. Stripe PaymentIntent, Adyen session, PayPal order).'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID or number'
      parameter name: :order_token, in: :query, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          payment_method_id: { type: :string, example: 'pm_abc123', description: 'Payment method ID' },
          amount: { type: :string, example: '99.99', description: 'Payment amount (defaults to order total minus store credits)' },
          external_data: { type: :object, description: 'Provider-specific data passed to the gateway' }
        },
        required: %w[payment_method_id]
      }

      response '201', 'payment session created' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { payment_method_id: payment_method.prefixed_id } }

        schema '$ref' => '#/components/schemas/StorePaymentSession'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('pending')
          expect(data['payment_method_id']).to eq(payment_method.prefixed_id)
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { 'invalid' }
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
    parameter name: :order_id, in: :path, type: :string, required: true,
              description: 'Order ID or number'
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Payment session ID'
    parameter name: :order_token, in: :query, type: :string, required: false,
              description: 'Order token for guest access'

    get 'Get payment session' do
      tags 'Checkout'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single payment session with its current status and provider data.'

      response '200', 'payment session found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { payment_session.to_param }

        schema '$ref' => '#/components/schemas/StorePaymentSession'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment_session.prefixed_id)
          expect(data['status']).to eq('pending')
        end
      end

      response '404', 'payment session not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end

    patch 'Update payment session' do
      tags 'Checkout'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a payment session. Delegates to the payment gateway to sync changes with the provider.'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :string, example: '50.00', description: 'Updated payment amount' },
          external_data: { type: :object, description: 'Provider-specific data to update' }
        }
      }

      response '200', 'payment session updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { payment_session.to_param }
        let(:body) { { amount: '50.00' } }

        schema '$ref' => '#/components/schemas/StorePaymentSession'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment_session.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/payment_sessions/{id}/complete' do
    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: 'Authorization', in: :header, type: :string, required: false,
              description: 'Bearer token for authenticated customers'
    parameter name: :order_id, in: :path, type: :string, required: true,
              description: 'Order ID or number'
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Payment session ID'
    parameter name: :order_token, in: :query, type: :string, required: false,
              description: 'Order token for guest access'

    patch 'Complete payment session' do
      tags 'Checkout'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Completes a payment session by confirming the payment with the provider. This triggers payment capture/authorization and order completion.'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          session_result: { type: :string, description: 'Provider-specific session result token' },
          external_data: { type: :object, description: 'Provider-specific completion data' }
        }
      }

      response '200', 'payment session completed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { payment_session.to_param }
        let(:body) { { session_result: 'success' } }

        schema '$ref' => '#/components/schemas/StorePaymentSession'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('completed')
        end
      end

      response '404', 'payment session not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'invalid' }
        let(:body) { { session_result: 'success' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end
  end
end
