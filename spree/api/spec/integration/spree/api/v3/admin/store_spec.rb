# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Store API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  let(:store) { @default_store }
  let!(:market) { create(:market, store: store) }

  # Reload to drop any in-memory mutations left over from earlier rolled-back
  # examples (the shared `@default_store` AR instance survives the suite).
  before { store.reload }

  path '/api/v3/admin/store' do
    get 'Get the current store' do
      tags 'Configuration'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the current store configuration. The store is resolved from the request context (host or admin selection); there is no `id` parameter.'
      admin_scope :read, :settings

      admin_sdk_example <<~JS
        const store = await client.store.get()
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'current store' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema '$ref' => '#/components/schemas/Store'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(store.prefixed_id)
          expect(data['id']).to start_with('store_')
          expect(data['name']).to eq(store.name)
          expect(data['url']).to eq(store.storefront_url)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update the current store' do
      tags 'Configuration'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates the current store configuration.'
      admin_scope :write, :settings

      admin_sdk_example <<~JS
        const store = await client.store.update({
          name: 'My Store'
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'My Store' },
          preferred_admin_locale: { type: :string, example: 'en' },
          preferred_timezone: { type: :string, example: 'UTC' },
          preferred_weight_unit: { type: :string, example: 'kg' },
          preferred_unit_system: { type: :string, example: 'metric' }
        }
      }

      response '200', 'store updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Renamed Store' } }

        schema '$ref' => '#/components/schemas/Store'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Renamed Store')
          expect(data['id']).to eq(store.prefixed_id)
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
