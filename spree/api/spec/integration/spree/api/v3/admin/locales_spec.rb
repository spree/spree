# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Locales API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  before { configure_supported_locales(store, %w[en de fr]) }

  path '/api/v3/admin/locales' do
    get 'List supported locales' do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Returns the locales a merchant can translate content into for the current store, with the default and right-to-left flags."
      admin_scope :read, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'locales found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.pluck('code')).to include('en', 'de', 'fr')
          expect(data.find { |l| l['code'] == 'en' }['default']).to be(true)
        end
      end
    end
  end
end
