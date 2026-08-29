# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Catalogs API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:catalog) { create(:catalog, store: store, name: 'Wholesale') }

  path '/api/v3/admin/catalogs' do
    get 'List catalogs' do
      tags 'Catalogs'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the store catalogs — product assortments with an optional price list, shown to audiences through assignments.'
      admin_scope :read, :products

      admin_sdk_example 'catalogs/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'catalogs found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(catalog.prefixed_id)
        end
      end
    end

    post 'Create a catalog' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a catalog. Add products and assign audiences (customer group, or company subtree) afterwards.'
      admin_scope :write, :products

      admin_sdk_example 'catalogs/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'VIP Assortment' },
          active: { type: :boolean, example: true },
          price_list_id: { type: :string, nullable: true,
                           description: 'Price list pricing this catalog; omit for assortment-only (base prices). A catalog with an empty assortment prices without restricting visibility; import or curate products to make it restrictive.',
                           example: 'pl_86Rf07xd4z' }
        },
        required: ['name']
      }

      let(:'x-spree-api-key') { secret_api_key.plaintext_token }

      response '201', 'catalog created' do
        let(:body) { { name: 'VIP Assortment' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('VIP Assortment')
        end
      end

      response '422', 'invalid request' do
        let(:body) { { active: true } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/catalogs/{id}/assign' do
    post 'Assign a catalog to an audience' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Shows the catalog to an audience. A company assignment covers the node and its whole subtree.'
      admin_scope :write, :products

      admin_sdk_example 'catalogs/assign'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          assignable_type: { type: :string, enum: %w[customer_group company],
                             example: 'company' },
          assignable_id: { type: :string, example: 'comp_86Rf07xd4z' }
        },
        required: %w[assignable_type assignable_id]
      }

      let(:'x-spree-api-key') { secret_api_key.plaintext_token }
      let(:id) { catalog.prefixed_id }

      response '201', 'catalog assigned' do
        let!(:company) { create(:company, store: store) }
        let(:body) { { assignable_type: 'company', assignable_id: company.prefixed_id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['assignable_type']).to eq('company')
        end
      end
    end
  end
  path '/api/v3/admin/catalogs/{catalog_id}/products' do
    get 'List catalog products' do
      tags 'Catalogs'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "The catalog's curated assortment, listed by product name — membership carries no order."
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true

      response '200', 'products found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('Product')

        run_test!
      end
    end

    post 'Add products to a catalog' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Curates products into the assortment in bulk. Already-present products are skipped; the count reports what was added.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { product_ids: { type: :array, items: { type: :string }, example: ['prod_abc123'] } },
        required: %w[product_ids]
      }

      response '201', 'products added' do
        let!(:product) { create(:product, store: store) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let(:body) { { product_ids: [product.prefixed_id] } }

        run_test! do |response|
          expect(JSON.parse(response.body)['added_count']).to eq(1)
        end
      end
    end

    delete 'Remove products from a catalog' do
      tags 'Catalogs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes products from the assortment in bulk. Ids that are not members are ignored; the count reports what was removed.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :catalog_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { product_ids: { type: :array, items: { type: :string }, example: ['prod_abc123'] } },
        required: %w[product_ids]
      }

      response '200', 'products removed' do
        let!(:product) { create(:product, store: store) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:catalog_id) { catalog.prefixed_id }
        let(:body) { { product_ids: [product.prefixed_id] } }

        before { catalog.add_products([product.id]) }

        run_test! do |response|
          expect(JSON.parse(response.body)['removed_count']).to eq(1)
        end
      end
    end
  end

end
