# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Credit Cards API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:credit_card) { create(:credit_card, user: user) }

  path '/api/v3/store/customer/credit_cards' do
    get 'List saved credit cards' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all saved credit cards for the authenticated customer'

      sdk_example <<~JS
        const cards = await client.store.customer.creditCards.list({}, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'credit cards found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreCreditCard' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].first).to include('id', 'cc_type', 'last_digits', 'month', 'year')
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

  path '/api/v3/store/customer/credit_cards/{id}' do
    get 'Get a credit card' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a saved credit card by its ID'

      sdk_example <<~JS
        const card = await client.store.customer.creditCards.get('cc_abc123', {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'credit card found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { credit_card.to_param }

        schema '$ref' => '#/components/schemas/StoreCreditCard'

        run_test!
      end

      response '404', 'credit card not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a credit card' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes a saved credit card from the customer account'

      sdk_example <<~JS
        await client.store.customer.creditCards.delete('cc_abc123', {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'credit card deleted' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { credit_card.to_param }

        run_test!
      end

      response '404', 'credit card not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
