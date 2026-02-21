# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Taxons API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:taxonomy) { create(:taxonomy, store: store) }
  let!(:root_taxon) { taxonomy.root }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy, parent: root_taxon) }
  let!(:child_taxon) { create(:taxon, taxonomy: taxonomy, parent: taxon) }
  let!(:product) { create(:product, stores: [store], status: 'active', taxons: [taxon]) }
  let!(:other_store) { create(:store) }
  let!(:other_taxonomy) { create(:taxonomy, store: other_store) }
  let!(:other_taxon) { create(:taxon, taxonomy: other_taxonomy) }

  path '/api/v3/store/taxons' do
    get 'List taxons' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a paginated list of taxons (categories) for the current store'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: 'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name'

      response '200', 'taxons found' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreTaxon' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].size).to be >= 1
          # Should not include taxons from other stores
          ids = data['data'].map { |t| t['id'] }
          expect(ids).not_to include(other_taxon.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/taxons/{id}' do
    get 'Get a taxon' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a single taxon by permalink or prefix ID'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Taxon permalink (e.g., categories/clothing/shirts) or prefix ID (e.g., taxon_abc123)'
      parameter name: :includes, in: :query, type: :string, required: false,
                description: 'Include associations (children, products, parent)'

      response '200', 'taxon found by permalink' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { taxon.permalink }

        schema '$ref' => '#/components/schemas/StoreTaxon'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq(taxon.name)
        end
      end

      response '200', 'taxon found by prefix ID' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { taxon.to_param }

        schema '$ref' => '#/components/schemas/StoreTaxon'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq(taxon.name)
        end
      end

      response '404', 'taxon not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { 'non-existent-permalink' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'taxon from other store not accessible' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { other_taxon.permalink }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:id) { taxon.permalink }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/taxons/{taxon_id}/products' do
    get 'List products in a taxon' do
      tags 'Product Catalog'
      produces 'application/json'
      security [api_key: []]
      description 'Returns a paginated list of products belonging to the specified taxon'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :taxon_id, in: :path, type: :string, required: true,
                description: 'Taxon permalink or prefix ID'
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'products found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:taxon_id) { taxon.to_param }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreProduct' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].size).to eq(1)
          expect(data['data'].first['id']).to eq(product.prefixed_id)
        end
      end

      response '404', 'taxon not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:taxon_id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:taxon_id) { taxon.to_param }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
