# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Option Types API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:option_type) { create(:option_type) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/option_types' do
    get 'List option types' do
      tags 'Option Types'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of option types.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'

      response '200', 'option types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('OptionType')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to be >= 1
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create an option type' do
      tags 'Option Types'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a new option type. Supports nested option values.

        Option values can be provided inline and will be created or updated by name.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'color' },
          presentation: { type: :string, example: 'Color' },
          position: { type: :integer, example: 1 },
          filterable: { type: :boolean, example: true },
          option_values: {
            type: :array,
            items: {
              type: :object,
              properties: {
                name: { type: :string, example: 'red' },
                presentation: { type: :string, example: 'Red' },
                position: { type: :integer }
              }
            }
          }
        },
        required: %w[name presentation]
      }

      response '201', 'option type created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'material', presentation: 'Material' } }

        schema '$ref' => '#/components/schemas/OptionType'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('material')
          expect(data['presentation']).to eq('Material')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '', presentation: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/option_types/{id}' do
    get 'Get an option type' do
      tags 'Option Types'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single option type by prefixed ID, including its option values.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Option type prefixed ID'

      response '200', 'option type found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { option_type.prefixed_id }

        schema '$ref' => '#/components/schemas/OptionType'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(option_type.prefixed_id)
        end
      end

      response '404', 'option type not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'ot_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update an option type' do
      tags 'Option Types'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates an option type. Supports updating nested option values.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Option type prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'color' },
          presentation: { type: :string, example: 'Color' },
          position: { type: :integer, example: 1 },
          filterable: { type: :boolean, example: true },
          option_values: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :string, description: 'Existing option value ID to update' },
                name: { type: :string, example: 'red' },
                presentation: { type: :string, example: 'Red' },
                position: { type: :integer }
              }
            }
          }
        }
      }

      response '200', 'option type updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { option_type.prefixed_id }
        let(:body) { { presentation: 'Updated Presentation' } }

        schema '$ref' => '#/components/schemas/OptionType'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['presentation']).to eq('Updated Presentation')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { option_type.prefixed_id }
        let(:body) { { presentation: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete an option type' do
      tags 'Option Types'
      security [api_key: [], bearer_auth: []]
      description 'Deletes an option type.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Option type prefixed ID'

      response '204', 'option type deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { option_type.prefixed_id }

        run_test!
      end
    end
  end
end
