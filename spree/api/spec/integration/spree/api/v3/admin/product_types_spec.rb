# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Product Types API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product_type) { create(:product_type, name: 'T-Shirt') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/product_types' do
    get 'List product types' do
      tags 'Product Types'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns a paginated list of product types.

        A product type is a back-office template: it seeds option types and
        categories onto products created with it, and defines which custom
        fields those products' forms show. It is not exposed on the Store API.
      DESC
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'product types found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('ProductType')

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

    post 'Create a product type' do
      tags 'Product Types'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Creates a product type.

        `option_type_ids` and `category_ids` seed products created with this
        type. `custom_field_definitions` is a replace-set of the definitions the
        product form renders, in `sort_order`. `required` is advisory — the
        dashboard marks the field, but a blank value is never rejected.
      DESC
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Hoodie' },
          fulfillment_types: {
            type: :array,
            items: { type: :string },
            example: ['shipping'],
            description: 'How products of this type can be delivered.'
          },
          option_type_ids: {
            type: :array,
            items: { type: :string },
            description: 'Option types seeded onto products created with this type.'
          },
          category_ids: {
            type: :array,
            items: { type: :string },
            description: 'Categories seeded onto products created with this type.'
          },
          custom_field_definitions: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :string, description: 'Prefixed custom field definition id.' },
                required: { type: :boolean },
                sort_order: { type: :integer }
              }
            }
          }
        },
        required: ['name']
      }

      response '201', 'product type created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Hoodie', fulfillment_types: ['shipping'] } }

        schema '$ref' => '#/components/schemas/ProductType'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Hoodie')
          expect(data['fulfillment_types']).to eq(['shipping'])
        end
      end

      response '422', 'unprocessable entity' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/product_types/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Product type ID'

    get 'Retrieve a product type' do
      tags 'Product Types'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single product type with its option types, categories and custom fields.'
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'product type found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { product_type.prefixed_id }

        schema '$ref' => '#/components/schemas/ProductType'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product_type.prefixed_id)
        end
      end

      response '404', 'product type not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'pt_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a product type' do
      tags 'Product Types'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Updates a product type.

        Changes never modify products that already carry the type — use
        `apply_to_products` to backfill those.
      DESC
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Premium T-Shirt' },
          fulfillment_types: { type: :array, items: { type: :string } },
          option_type_ids: { type: :array, items: { type: :string } },
          category_ids: { type: :array, items: { type: :string } },
          custom_field_definitions: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :string },
                required: { type: :boolean },
                sort_order: { type: :integer }
              }
            }
          }
        }
      }

      response '200', 'product type updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { product_type.prefixed_id }
        let(:body) { { name: 'Premium T-Shirt' } }

        schema '$ref' => '#/components/schemas/ProductType'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Premium T-Shirt')
        end
      end
    end

    delete 'Delete a product type' do
      tags 'Product Types'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a product type. Types still used by products cannot be deleted.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'product type deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { product_type.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/product_types/{id}/apply_to_products' do
    parameter name: :id, in: :path, type: :string, description: 'Product type ID'

    post 'Apply a product type to its existing products' do
      tags 'Product Types'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Backfills the type's option types and categories onto the products that
        already carry it. Additive and idempotent — nothing is removed, and
        re-running is safe.

        Runs in the background; the response reports how many products the type
        currently has.
      DESC
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '202', 'backfill accepted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { product_type.prefixed_id }

        schema type: :object, properties: { products_count: { type: :integer } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to have_key('products_count')
        end
      end
    end
  end
end
