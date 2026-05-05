# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Payment Methods API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:payment_method) { create(:check_payment_method, stores: [store]) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/payment_methods' do
    get 'List payment methods' do
      tags 'Configuration'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the store\'s configured payment methods. Use `source_required: true` to know which methods need a saved source.'
      admin_scope :read, :settings

      admin_sdk_example <<~JS
        const { data: paymentMethods } = await client.paymentMethods.list()
      JS

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

  path '/api/v3/admin/payment_methods/{id}' do
    let(:id) { payment_method.prefixed_id }

    get 'Show a payment method' do
      tags 'Configuration'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a payment method by ID.'
      admin_scope :read, :settings

      admin_sdk_example <<~JS
        const paymentMethod = await client.paymentMethods.get('pm_UkLWZg9DAJ')
      JS

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
