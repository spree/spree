# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Customer Store Credits API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:customer) { create(:user) }
  let!(:category) { create(:store_credit_category) }
  let!(:store_credit) { create(:store_credit, user: customer, store: store, amount: 50.00, category: category) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/customers/{customer_id}/store_credits' do
    let(:customer_id) { customer.prefixed_id }

    get 'List customer store credits' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns store credits issued to the customer.'
      admin_scope :read, :store_credits

      admin_sdk_example <<~JS
        const { data: storeCredits } = await client.customers.storeCredits.list('cus_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., category, store, created_by). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., amount,amount_used,memo,currency). id is always included.'

      response '200', 'store credits found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Issue a store credit to a customer' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description '`created_by` is set automatically from the authenticated admin.'
      admin_scope :write, :store_credits

      admin_sdk_example <<~JS
        const credit = await client.customers.storeCredits.create('cus_UkLWZg9DAJ', {
          amount: 25.00,
          currency: 'USD',
          category_id: 1,
          memo: 'Goodwill credit',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[amount currency category_id],
        properties: {
          amount: { type: :number, example: 50.0 },
          currency: { type: :string, example: 'USD' },
          category_id: { type: :string, description: 'StoreCreditCategory ID' },
          memo: { type: :string }
        }
      }

      response '201', 'store credit created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { amount: 25.00, currency: 'USD', category_id: category.id, memo: 'Goodwill' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          created = Spree::StoreCredit.find_by_prefix_id(data['id'])
          expect(created.memo).to eq('Goodwill')
        end
      end
    end
  end

  path '/api/v3/admin/customers/{customer_id}/store_credits/{id}' do
    let(:customer_id) { customer.prefixed_id }
    let(:id) { store_credit.prefixed_id }

    patch 'Update a store credit' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Update memo / category / amount. The amount can only be changed if `amount_used == 0`.'
      admin_scope :write, :store_credits

      admin_sdk_example <<~JS
        const credit = await client.customers.storeCredits.update(
          'cus_UkLWZg9DAJ',
          'sc_UkLWZg9DAJ',
          { memo: 'Reissued for damaged shipment' },
        )
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :number },
          category_id: { type: :string },
          memo: { type: :string }
        }
      }

      response '200', 'store credit updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { memo: 'Updated' } }

        run_test! do |_response|
          expect(store_credit.reload.memo).to eq('Updated')
        end
      end
    end

    delete 'Delete a store credit' do
      tags 'Customers'
      security [api_key: [], bearer_auth: []]
      description 'Deletes an unused store credit (amount_used == 0). Returns 422 otherwise.'
      admin_scope :write, :store_credits

      admin_sdk_example <<~JS
        await client.customers.storeCredits.delete('cus_UkLWZg9DAJ', 'sc_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'store credit deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
