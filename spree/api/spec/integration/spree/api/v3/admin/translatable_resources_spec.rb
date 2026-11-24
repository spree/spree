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

      admin_sdk_example 'translatable-resources/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'translatable resources found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.list(
          type: :object,
          properties: {
            resource_type: { type: :string, example: 'product' },
            fields: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  key: { type: :string, example: 'name' },
                  type: { type: :string, example: 'string', description: 'How the field is edited: `string`, `text` or `html`' }
                },
                required: %w[key type]
              }
            },
            readable: { type: :boolean, description: 'Whether the caller may read records of this type' }
          },
          required: %w[resource_type fields readable]
        )

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data).to be_an(Array)
          expect(data.pluck('resource_type')).to include('product')
          expect(data.find { |r| r['resource_type'] == 'product' }['readable']).to be(true)
        end
      end
    end
  end
end
