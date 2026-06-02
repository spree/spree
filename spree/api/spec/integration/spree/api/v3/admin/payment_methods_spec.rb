# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Payment Methods API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:payment_method) { create(:check_payment_method) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/payment_methods' do
    get 'List payment methods' do
      tags 'Configuration'
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
  end

  path '/api/v3/admin/payment_methods/types' do
    get 'List available payment provider types' do
      tags 'Configuration'
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
          Spree::PaymentMethod::StoreCredit.create!(name: 'Store Credit')
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
      tags 'Configuration'
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
  end
end
