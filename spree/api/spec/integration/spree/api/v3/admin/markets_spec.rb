# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Markets API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:market) { create(:market, store: store, name: 'EU') }

  path '/api/v3/admin/markets' do
    get 'List markets' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the markets configured for the current store. Read-only:
        write surface lives in the legacy Rails admin pending the
        Channel / Catalog rework (see `docs/plans/6.0-channels-catalogs-b2b.md`).
      DESC
      admin_scope :read, :settings

      admin_sdk_example 'markets/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :limit, in: :query, type: :integer, required: false
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false
      parameter name: :sort, in: :query, type: :string, required: false
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed. Supported: `countries`.'

      response '200', 'markets found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Market')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(market.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/markets/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    get 'Get a market' do
      tags 'Pricing'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :settings

      admin_sdk_example 'markets/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false

      response '200', 'market found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { market.prefixed_id }

        schema '$ref' => '#/components/schemas/Market'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(market.prefixed_id)
        end
      end

      response '404', 'market not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'market_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
