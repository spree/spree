# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Taxonomies API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:taxonomy) { create(:taxonomy, store: store) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/taxonomies' do
    get 'List taxonomies' do
      tags 'Taxonomies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of taxonomies for the current store.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'taxonomies found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('AdminTaxonomy')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to be >= 1
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a taxonomy' do
      tags 'Taxonomies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new taxonomy.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Categories' },
          position: { type: :integer, example: 1 }
        },
        required: %w[name]
      }

      response '201', 'taxonomy created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'New Taxonomy' } }

        schema '$ref' => '#/components/schemas/AdminTaxonomy'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('New Taxonomy')
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

  path '/api/v3/admin/taxonomies/{id}' do
    get 'Get a taxonomy' do
      tags 'Taxonomies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single taxonomy by prefixed ID.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Taxonomy prefixed ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., root, taxons)'

      response '200', 'taxonomy found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { taxonomy.prefixed_id }

        schema '$ref' => '#/components/schemas/AdminTaxonomy'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(taxonomy.prefixed_id)
        end
      end

      response '404', 'taxonomy not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'txmy_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a taxonomy' do
      tags 'Taxonomies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a taxonomy. Only provided fields are updated.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Taxonomy prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Categories' },
          position: { type: :integer, example: 1 }
        }
      }

      response '200', 'taxonomy updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { taxonomy.prefixed_id }
        let(:body) { { name: 'Updated Taxonomy' } }

        schema '$ref' => '#/components/schemas/AdminTaxonomy'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Updated Taxonomy')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { taxonomy.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a taxonomy' do
      tags 'Taxonomies'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a taxonomy.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Taxonomy prefixed ID'

      response '204', 'taxonomy deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { taxonomy.prefixed_id }

        run_test!
      end
    end
  end
end
