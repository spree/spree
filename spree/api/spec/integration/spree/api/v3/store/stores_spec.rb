# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Store API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  path '/api/v3/store/store' do
    get 'Get current store' do
      tags 'Store'
      produces 'application/json'
      security [api_key: []]
      description 'Returns information about the current store based on the API key'

      sdk_example <<~JS
        const store = await client.store.store.get()
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'store found' do
        let(:'x-spree-api-key') { api_key.token }

        schema '$ref' => '#/components/schemas/StoreStore'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to be_present
          expect(data['name']).to eq(store.name)
          expect(data['url']).to eq(store.url)
        end
      end

      response '401', 'unauthorized - invalid API key' do
        let(:'x-spree-api-key') { 'invalid_key' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_token')
        end
      end

      response '401', 'unauthorized - missing API key' do
        let(:'x-spree-api-key') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
