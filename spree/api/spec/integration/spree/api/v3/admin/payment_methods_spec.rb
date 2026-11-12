# frozen_string_literal: true

require 'swagger_helper'

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
      filter_parameters_for

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
        Adds a payment method to the store. `type` is a shorthand from the
        payment method types endpoint, and `preferences` takes the values its
        preference schema declares (gateway credentials among them).
      DESC
      admin_scope :write, :settings

      admin_sdk_example 'payment-methods/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '201', 'payment method created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            type: 'check',
            name: 'Bank transfer',
            description: 'Pay by bank transfer within 14 days.',
            active: true,
            storefront_visible: true,
            capture_method: 'manual'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['type']).to eq('check')
          expect(data['name']).to eq('Bank transfer')
        end
      end

      response '422', 'unknown payment method type' do
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
      description 'Returns every registered payment provider with the JSON Schema of its `preferences`. `installed` marks a provider the store already has, which a "Provider" picker leaves out.'
      admin_scope :read, :settings

      admin_sdk_example 'payment-methods/types'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'provider types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before do
          # Install StoreCredit in the store so the entry is marked installed.
          # (Check is also installed via the let!(:payment_method), but other
          # tests in this file delete it, so it's order-dependent.)
          store.payment_methods.create!(type: 'Spree::PaymentMethod::StoreCredit', name: 'Store Credit')
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data).to be_an(Array)
          expect(data).to all(include('type', 'label'))
          installed = data.to_h { |entry| [entry['type'], entry['installed']] }
          expect(installed).to include('store_credit' => true, 'bogus' => false)
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
      description 'Updates a payment method. Its `type` is fixed once created.'
      admin_scope :write, :settings

      admin_sdk_example 'payment-methods/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      request_body_for

      response '200', 'payment method updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Cheque', storefront_visible: false, position: 2 } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Cheque')
        end
      end
    end
  end
end
