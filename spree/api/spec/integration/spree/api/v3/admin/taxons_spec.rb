# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Taxons API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  # ============================================
  # Flat taxon endpoints (index, show only)
  # ============================================

  path '/api/v3/admin/taxons' do
    get 'List taxons' do
      tags 'Taxons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a flat, paginated list of all taxons for the current store.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'

      response '200', 'taxons found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('AdminTaxon')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/taxons/{id}' do
    get 'Get a taxon' do
      tags 'Taxons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single taxon by prefixed ID.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Taxon prefixed ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., parent, children, ancestors)'

      response '200', 'taxon found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { taxon.prefixed_id }

        schema '$ref' => '#/components/schemas/AdminTaxon'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(taxon.prefixed_id)
        end
      end

      response '404', 'taxon not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'txn_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  # ============================================
  # Nested taxon endpoints (under taxonomies)
  # ============================================

  path '/api/v3/admin/taxonomies/{taxonomy_id}/taxons' do
    get 'List taxonomy taxons' do
      tags 'Taxons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of taxons belonging to a taxonomy.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :taxonomy_id, in: :path, type: :string, required: true, description: 'Taxonomy prefixed ID'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'taxons found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:taxonomy_id) { taxonomy.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('AdminTaxon')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a taxon' do
      tags 'Taxons'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new taxon within a taxonomy.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :taxonomy_id, in: :path, type: :string, required: true, description: 'Taxonomy prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'T-Shirts' },
          parent_id: { type: :string, description: 'Parent taxon prefixed ID' },
          position: { type: :integer },
          description: { type: :string },
          permalink: { type: :string },
          meta_title: { type: :string },
          meta_description: { type: :string },
          meta_keywords: { type: :string },
          hide_from_nav: { type: :boolean },
          sort_order: { type: :string, example: 'manual' }
        },
        required: %w[name]
      }

      response '201', 'taxon created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:taxonomy_id) { taxonomy.prefixed_id }
        let(:body) { { name: 'New Taxon', parent_id: taxonomy.root.id } }

        schema '$ref' => '#/components/schemas/AdminTaxon'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('New Taxon')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:taxonomy_id) { taxonomy.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/taxonomies/{taxonomy_id}/taxons/{id}' do
    get 'Get a taxonomy taxon' do
      tags 'Taxons'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single taxon within a taxonomy.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :taxonomy_id, in: :path, type: :string, required: true, description: 'Taxonomy prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Taxon prefixed ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., parent, children, ancestors)'

      response '200', 'taxon found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:taxonomy_id) { taxonomy.prefixed_id }
        let(:id) { taxon.prefixed_id }

        schema '$ref' => '#/components/schemas/AdminTaxon'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(taxon.prefixed_id)
        end
      end

      response '404', 'taxon not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:taxonomy_id) { taxonomy.prefixed_id }
        let(:id) { 'txn_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a taxon' do
      tags 'Taxons'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a taxon within a taxonomy. Only provided fields are updated.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :taxonomy_id, in: :path, type: :string, required: true, description: 'Taxonomy prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Taxon prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'T-Shirts' },
          parent_id: { type: :string, description: 'Parent taxon prefixed ID' },
          position: { type: :integer },
          description: { type: :string },
          permalink: { type: :string },
          meta_title: { type: :string },
          meta_description: { type: :string },
          meta_keywords: { type: :string },
          hide_from_nav: { type: :boolean },
          sort_order: { type: :string, example: 'manual' }
        }
      }

      response '200', 'taxon updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:taxonomy_id) { taxonomy.prefixed_id }
        let(:id) { taxon.prefixed_id }
        let(:body) { { name: 'Updated Taxon' } }

        schema '$ref' => '#/components/schemas/AdminTaxon'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Updated Taxon')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:taxonomy_id) { taxonomy.prefixed_id }
        let(:id) { taxon.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a taxon' do
      tags 'Taxons'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a taxon from a taxonomy.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :taxonomy_id, in: :path, type: :string, required: true, description: 'Taxonomy prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Taxon prefixed ID'

      response '204', 'taxon deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:taxonomy_id) { taxonomy.prefixed_id }
        let(:id) { taxon.prefixed_id }

        run_test!
      end
    end
  end
end
