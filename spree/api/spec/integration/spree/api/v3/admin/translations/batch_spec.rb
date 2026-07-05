# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Translations Batch API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  let!(:option_type) { create(:option_type, name: 'size', presentation: 'Size') }
  let!(:option_value) { create(:option_value, name: 'small', presentation: 'Small', option_type: option_type) }

  before { configure_supported_locales(store, %w[en de fr]) }

  path '/api/v3/admin/translations/batch' do
    post 'Batch upsert translations' do
      tags 'Settings'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Atomically upserts translations across many records of (possibly) different translatable resource types in one request — e.g. an option type and all its option values in one save. A flat list of independent registry writes; all entries succeed or none do.'
      admin_scope_note('`write_<resource>` for every resource type in the batch (for API-key authentication)')

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[translations],
        properties: {
          translations: {
            type: :array,
            items: {
              type: :object,
              required: %w[resource_type resource_id values],
              properties: {
                resource_type: { type: :string, description: 'Translatable resource type token, e.g. `option_type`' },
                resource_id: { type: :string, description: 'Prefixed id of the record' },
                values: {
                  type: :object,
                  description: 'Map of locale code to { field: value }',
                  additionalProperties: { type: :object, additionalProperties: true }
                }
              }
            }
          }
        }
      }

      response '200', 'translations upserted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            translations: [
              { resource_type: 'option_type',  resource_id: option_type.prefixed_id,  values: { de: { label: 'Größe' } } },
              { resource_type: 'option_value', resource_id: option_value.prefixed_id, values: { de: { label: 'Klein' } } }
            ]
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.size).to eq(2)
          Mobility.with_locale(:de) { expect(option_type.reload.presentation).to eq('Größe') }
        end
      end

      response '422', 'unsupported locale rolls back the whole batch' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          { translations: [{ resource_type: 'option_type', resource_id: option_type.prefixed_id, values: { es: { label: 'Talla' } } }] }
        end

        run_test!
      end
    end
  end
end
