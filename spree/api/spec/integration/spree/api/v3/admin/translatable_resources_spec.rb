# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Translatable Resources API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/translatable_resources' do
    get 'List translatable resources' do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns every translatable resource type and its translatable fields (key + content type), so clients can render translation editors generically.'
      admin_scope :read, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'translatable resources found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data).to be_an(Array)
          expect(data.pluck('resource_type')).to include('product')
        end
      end
    end
  end
end
