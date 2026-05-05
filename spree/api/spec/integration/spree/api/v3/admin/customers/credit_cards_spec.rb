# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Customer Credit Cards API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:customer) { create(:user) }
  let!(:payment_method) { create(:credit_card_payment_method, stores: [store]) }
  let!(:credit_card) { create(:credit_card, user: customer, payment_method: payment_method) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/customers/{customer_id}/credit_cards' do
    let(:customer_id) { customer.prefixed_id }

    get 'List customer credit cards' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the customer\'s saved credit cards. Useful for off-session admin charges via `POST /admin/orders/:id/payments { source_id }`.'
      admin_scope :read, :customers

      admin_sdk_example <<~JS
        const { data: cards } = await client.customers.creditCards.list('cus_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., payment_method). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., brand,last4,month,year). id is always included.'

      response '200', 'credit cards found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  path '/api/v3/admin/customers/{customer_id}/credit_cards/{id}' do
    let(:customer_id) { customer.prefixed_id }
    let(:id) { credit_card.prefixed_id }

    get 'Show a customer credit card' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a saved credit card by ID.'
      admin_scope :read, :customers

      admin_sdk_example <<~JS
        const card = await client.customers.creditCards.get('cus_UkLWZg9DAJ', 'cc_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., payment_method). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., brand,last4,month,year). id is always included.'

      response '200', 'credit card found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(credit_card.prefixed_id)
        end
      end
    end

    delete 'Delete a customer credit card' do
      tags 'Customers'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a saved credit card.'
      admin_scope :write, :customers

      admin_sdk_example <<~JS
        await client.customers.creditCards.delete('cus_UkLWZg9DAJ', 'cc_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'credit card deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
