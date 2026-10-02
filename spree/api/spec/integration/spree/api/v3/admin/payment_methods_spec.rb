# frozen_string_literal: true

require 'swagger_helper'

# Create and update accept the same attributes (plus `type` on create), so
# they document one shape.
PAYMENT_METHOD_WRITE_PROPERTIES = {
  name: { type: :string, example: 'Pay by check' },
  description: { type: :string, nullable: true },
  active: { type: :boolean },
  storefront_visible: { type: :boolean },
  capture_method: { type: :string, nullable: true, enum: %w[checkout on_dispatch manual],
                    description: 'When the customer is charged. `null` follows the store setting.' },
  auto_capture: { type: :boolean, nullable: true, description: 'Legacy flag. Prefer `capture_method`.' },
  position: { type: :integer },
  preferences: { type: :object,
                 description: 'Provider configuration, per the `preference_schema` from `GET /payment_methods/types`. ' \
                              'Unknown keys are ignored, and a masked secret sent back unchanged keeps the stored value.' },
  metadata: { type: :object }
}.freeze

RSpec.describe 'Admin Payment Methods API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:payment_method) { create(:check_payment_method) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/payment_methods' do
    get 'List payment methods' do
      tags 'Payment Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the store\'s configured payment methods. Use `source_required: true` to know which methods need a saved source.'
      admin_scope :read, :settings

      admin_sdk_example 'payment-methods/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand. Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,type,active). id is always included.'

      response '200', 'payment methods found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a payment method' do
      tags 'Payment Methods'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Installs a payment provider on the store. `type` picks the provider by
        its shorthand from `GET /payment_methods/types` (for example `check`,
        `store_credit` or `bogus`) and cannot be changed afterwards.
      DESC
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[type name],
        properties: {
          type: { type: :string, example: 'check', description: 'Provider shorthand from `GET /payment_methods/types`.' },
          **PAYMENT_METHOD_WRITE_PROPERTIES
        }
      }

      response '201', 'payment method created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'check', name: 'Pay by check', active: true } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Pay by check')
          expect(data['type']).to eq('check')
        end
      end

      response '422', 'unknown provider type' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { type: 'not_a_provider', name: 'Mystery' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/payment_methods/types' do
    get 'List available payment provider types' do
      tags 'Payment Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the registered Spree::PaymentMethod subclasses that can be used to create new payment methods. Useful for populating a "Provider" dropdown in admin UIs.'
      admin_scope :read, :settings

      admin_sdk_example 'payment-methods/types'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'provider types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before do
          # Install StoreCredit in the store so we can verify the picker
          # filters out providers that are already configured. (Check is
          # also installed via the let!(:payment_method), but other tests
          # in this file delete it, so it's order-dependent.)
          store.payment_methods.create!(type: 'Spree::PaymentMethod::StoreCredit', name: 'Store Credit')
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data).to be_an(Array)
          expect(data).to all(include('type', 'label'))
          # StoreCredit was just installed → must be filtered out.
          expect(data.map { |t| t['type'] }).not_to include('store_credit')
          # Bogus is registered but not installed → must show up.
          expect(data.map { |t| t['type'] }).to include('bogus')
        end
      end
    end
  end

  path '/api/v3/admin/payment_methods/{id}' do
    let(:id) { payment_method.prefixed_id }

    get 'Show a payment method' do
      tags 'Payment Methods'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a payment method by ID.'
      admin_scope :read, :settings

      admin_sdk_example 'payment-methods/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand. Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,type,active). id is always included.'

      response '200', 'payment method found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(payment_method.prefixed_id)
        end
      end
    end

    patch 'Update a payment method' do
      tags 'Payment Methods'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a payment method. Its provider `type` is fixed at creation.'
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: PAYMENT_METHOD_WRITE_PROPERTIES
      }

      response '200', 'payment method updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Check (Updated)', capture_method: 'manual' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Check (Updated)')
          expect(payment_method.reload.capture_method).to eq('manual')
        end
      end
    end
  end
end
