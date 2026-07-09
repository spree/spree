# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Collections API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:collection) { create(:collection, store: store, name: 'Summer Sale') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/collections' do
    get 'List collections' do
      tags 'Collections'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of the store\'s collections.'
      admin_scope :read, :collections

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., custom_fields, translations).'

      response '200', 'collections found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Collection')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a collection' do
      tags 'Collections'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a manual or automatic (rule-based) collection. For automatic collections, send the full desired rule set under `rules`.'
      admin_scope :write, :collections

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'On Sale' },
          automatic: { type: :boolean, example: true },
          rules_match_policy: { type: :string, enum: %w[all any], example: 'all' },
          sort_order: { type: :string, example: 'manual' },
          permalink: { type: :string },
          description: { type: :string },
          meta_title: { type: :string },
          meta_description: { type: :string },
          meta_keywords: { type: :string },
          hide_from_nav: { type: :boolean, example: false },
          rules: {
            type: :array,
            description: 'Full desired rule set. Entries with an id update, id-less entries create, omitted rules are removed.',
            items: {
              type: :object,
              properties: {
                id: { type: :string, example: 'crule_abc123' },
                type: { type: :string, example: 'Spree::CollectionRules::Tag' },
                value: { type: :string, example: 'summer' },
                match_policy: { type: :string, example: 'contains' }
              }
            }
          }
        },
        required: %w[name]
      }

      response '201', 'collection created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            name: 'On Sale',
            automatic: true,
            rules_match_policy: 'any',
            rules: [{ type: 'Spree::CollectionRules::Tag', value: 'summer', match_policy: 'contains' }]
          }
        end

        schema '$ref' => '#/components/schemas/Collection'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('On Sale')
          expect(data['rules'].length).to eq(1)
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

  path '/api/v3/admin/collections/{id}' do
    get 'Get a collection' do
      tags 'Collections'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single collection by ID, including its rules.'
      admin_scope :read, :collections

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Collection ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., custom_fields, translations).'

      response '200', 'collection found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { collection.prefixed_id }

        schema '$ref' => '#/components/schemas/Collection'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(collection.prefixed_id)
        end
      end

      response '404', 'collection not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'coll_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a collection' do
      tags 'Collections'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a collection. Send `position` to reorder it within the flat list; send the full `rules` set to sync automatic rules.'
      admin_scope :write, :collections

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Collection ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Winter Sale' },
          permalink: { type: :string },
          description: { type: :string },
          meta_title: { type: :string },
          meta_description: { type: :string },
          meta_keywords: { type: :string },
          hide_from_nav: { type: :boolean },
          sort_order: { type: :string },
          automatic: { type: :boolean },
          rules_match_policy: { type: :string, enum: %w[all any] },
          position: { type: :integer, description: 'Reorders the collection within the flat list (acts_as_list)' },
          rules: {
            type: :array,
            description: 'Full desired rule set (see create).',
            items: {
              type: :object,
              properties: {
                id: { type: :string },
                type: { type: :string },
                value: { type: :string },
                match_policy: { type: :string }
              }
            }
          }
        }
      }

      response '200', 'collection updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { collection.prefixed_id }
        let(:body) { { name: 'Winter Sale' } }

        schema '$ref' => '#/components/schemas/Collection'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Winter Sale')
        end
      end
    end

    delete 'Delete a collection' do
      tags 'Collections'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a collection.'
      admin_scope :write, :collections

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Collection ID'

      response '204', 'collection deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { collection.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/collections/{collection_id}/products' do
    get 'List collection products' do
      tags 'Collections'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Products curated in the collection, ordered by their membership position.'
      admin_scope :read, :collections

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :collection_id, in: :path, type: :string, required: true, description: 'Collection ID'

      response '200', 'products found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:collection_id) { collection.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('Product')

        run_test!
      end
    end

    post 'Add a product to a collection' do
      tags 'Collections'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Curates a product into the collection (appended to the end).'
      admin_scope :write, :collections

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :collection_id, in: :path, type: :string, required: true, description: 'Collection ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { product_id: { type: :string, example: 'prod_abc123' } },
        required: %w[product_id]
      }

      response '201', 'product added' do
        let!(:product) { create(:product, stores: [store]) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:collection_id) { collection.prefixed_id }
        let(:body) { { product_id: product.prefixed_id } }

        schema '$ref' => '#/components/schemas/Product'

        run_test!
      end
    end
  end

  path '/api/v3/admin/collections/{collection_id}/products/{id}/reposition' do
    patch 'Reposition a collection product' do
      tags 'Collections'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Moves a product to a new index among the collection\'s products.'
      admin_scope :write, :collections

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :collection_id, in: :path, type: :string, required: true, description: 'Collection ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { new_position: { type: :integer, description: '0-based index among the collection\'s products' } },
        required: %w[new_position]
      }

      response '204', 'product repositioned' do
        let!(:product) { create(:product, stores: [store]) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:collection_id) { collection.prefixed_id }
        let(:id) { product.prefixed_id }
        let(:body) { { new_position: 0 } }

        before { Spree::ProductCollection.create!(collection: collection, product: product, position: 1) }

        run_test!
      end
    end
  end
end
