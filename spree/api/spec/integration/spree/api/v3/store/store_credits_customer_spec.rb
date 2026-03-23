# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Customer Store Credits API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:store_credit) { create(:store_credit, user: user, store: store, currency: 'USD', amount: 100) }

  path '/api/v3/store/customers/me/store_credits' do
    get 'List store credits' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns store credits for the authenticated customer, filtered by current store and currency. Supports Ransack filtering.'

      sdk_example <<~JS
        const credits = await client.customer.storeCredits.list({}, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., amount,currency). id is always included.'

      response '200', 'store credits found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreCredit' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].first).to include('id', 'amount', 'amount_remaining', 'currency')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/customers/me/store_credits/{id}' do
    get 'Get a store credit' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]

      sdk_example <<~JS
        const credit = await client.customer.storeCredits.get('credit_abc123', {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., amount,currency). id is always included.'

      response '200', 'store credit found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { store_credit.to_param }

        schema '$ref' => '#/components/schemas/StoreCredit'

        run_test!
      end

      response '404', 'store credit not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
