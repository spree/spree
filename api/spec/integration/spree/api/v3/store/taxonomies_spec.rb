# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Taxonomies API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:taxonomy) { create(:taxonomy, store: store) }
  let!(:taxonomy2) { create(:taxonomy, store: store) }
  let!(:other_store) { create(:store) }
  let!(:other_taxonomy) { create(:taxonomy, store: other_store) }

  path '/api/v3/store/taxonomies' do
    get 'List taxonomies' do
      tags 'Taxonomies'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a list of taxonomies (category hierarchies) for the current store'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :includes, in: :query, type: :string, required: false,
                description: 'Include root taxon'

      response '200', 'taxonomies found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreTaxonomy' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to be >= 2
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/taxonomies/{id}' do
    get 'Get a taxonomy' do
      tags 'Taxonomies'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single taxonomy with its taxon tree'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Taxonomy ID (prefixed)'
      parameter name: :includes, in: :query, type: :string, required: false,
                description: 'Include taxons'

      response '200', 'taxonomy found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { taxonomy.to_param }

        schema '$ref' => '#/components/schemas/StoreTaxonomy'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq(taxonomy.name)
        end
      end

      response '404', 'taxonomy not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { 'tax_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'taxonomy from other store' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { other_taxonomy.to_param }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
