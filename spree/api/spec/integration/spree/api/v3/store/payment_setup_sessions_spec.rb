# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Payment Setup Sessions API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let!(:payment_setup_session) do
    create(:payment_setup_session,
           customer: user,
           payment_method: payment_method,
           external_data: { 'client_secret' => 'secret_123' })
  end

  path '/api/v3/store/customer/payment_setup_sessions' do
    post 'Create payment setup session' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new payment setup session for saving a payment method for future use. Delegates to the payment gateway to initialize a provider-specific setup flow (e.g. Stripe SetupIntent, Adyen zero-auth tokenization).'

      sdk_example <<~JS
        const session = await client.store.customer.paymentSetupSessions.create({
          payment_method_id: 'pm_abc123',
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          payment_method_id: { type: :string, example: 'pm_abc123', description: 'Payment method ID' },
          external_data: { type: :object, description: 'Provider-specific data passed to the gateway' }
        },
        required: %w[payment_method_id]
      }

      response '201', 'payment setup session created' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { payment_method_id: payment_method.prefixed_id } }

        schema '$ref' => '#/components/schemas/StorePaymentSetupSession'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('pending')
          expect(data['payment_method_id']).to eq(payment_method.prefixed_id)
          expect(data['external_client_secret']).to be_present
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:body) { { payment_method_id: payment_method.prefixed_id } }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end

      response '404', 'payment method not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { payment_method_id: 'invalid' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end
  end

  path '/api/v3/store/customer/payment_setup_sessions/{id}' do
    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: 'Authorization', in: :header, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Payment setup session ID'

    get 'Get payment setup session' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a payment setup session with its current status and provider data.'

      sdk_example <<~JS
        const session = await client.store.customer.paymentSetupSessions.get('pss_abc123', {
          bearerToken: '<token>',
        })
      JS

      response '200', 'payment setup session found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { payment_setup_session.to_param }

        schema '$ref' => '#/components/schemas/StorePaymentSetupSession'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment_setup_session.prefixed_id)
          expect(data['status']).to eq('pending')
        end
      end

      response '404', 'payment setup session not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end
  end

  path '/api/v3/store/customer/payment_setup_sessions/{id}/complete' do
    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: 'Authorization', in: :header, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'Payment setup session ID'

    patch 'Complete payment setup session' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Completes a payment setup session by confirming the setup with the provider, resulting in a saved payment method.'

      sdk_example <<~JS
        const session = await client.store.customer.paymentSetupSessions.complete('pss_abc123', {}, {
          bearerToken: '<token>',
        })
      JS

      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          external_data: { type: :object, description: 'Provider-specific completion data' }
        }
      }

      response '200', 'payment setup session completed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { payment_setup_session.to_param }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/StorePaymentSetupSession'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('completed')
          expect(data['payment_source_id']).to be_present
          expect(data['payment_source_type']).to eq('Spree::CreditCard')
        end
      end

      response '404', 'payment setup session not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'invalid' }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/ErrorResponse'
        run_test!
      end
    end
  end
end
