# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Product Custom Fields API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product) }
  let!(:definition) { create(:metafield_definition, :short_text_field) }
  let!(:custom_field) do
    create(:metafield, resource: product, metafield_definition: definition, value: 'wool')
  end
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/products/{product_id}/custom_fields' do
    let(:product_id) { product.prefixed_id }

    get 'List product custom fields' do
      tags 'Products'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Returns the product's custom field values."
      admin_scope :read, :products

      admin_sdk_example <<~JS
        const { data: customFields } = await client.products.customFields.list('prod_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :product_id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., custom_field_definition). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., key,value,namespace). id is always included.'

      response '200', 'custom fields found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to eq(1)
          expect(data['data'].first['value']).to eq('wool')
          expect(data['data'].first['custom_field_definition_id']).to eq(definition.prefixed_id)
        end
      end
    end

    post 'Create a product custom field' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Sets a custom field value on the product. Requires an existing CustomFieldDefinition; pass its prefixed `cfdef_…` id."
      admin_scope :write, :products

      admin_sdk_example <<~JS
        const customField = await client.products.customFields.create('prod_UkLWZg9DAJ', {
          custom_field_definition_id: 'cfdef_AbC123XyZ',
          value: 'wool',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :product_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[custom_field_definition_id value],
        properties: {
          custom_field_definition_id: { type: :string, description: 'Prefixed `cfdef_…` id' },
          value: { description: 'Value matching the definition\'s `field_type`' }
        }
      }

      response '201', 'custom field created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:other_definition) { create(:metafield_definition, :long_text_field) }
        let(:body) do
          {
            custom_field_definition_id: other_definition.prefixed_id,
            value: 'A longer description'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['value']).to eq('A longer description')
          expect(data['custom_field_definition_id']).to eq(other_definition.prefixed_id)
        end
      end

      response '422', 'duplicate definition for the same product' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          { custom_field_definition_id: definition.prefixed_id, value: 'cotton' }
        end

        run_test!
      end
    end
  end

  path '/api/v3/admin/products/{product_id}/custom_fields/{id}' do
    let(:product_id) { product.prefixed_id }
    let(:id) { custom_field.prefixed_id }

    get 'Show a product custom field' do
      tags 'Products'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :product_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., custom_field_definition). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., key,value,namespace). id is always included.'

      response '200', 'custom field found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(custom_field.prefixed_id)
          expect(data['value']).to eq('wool')
        end
      end
    end

    patch 'Update a product custom field' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates the custom field\'s `value`. The linked definition cannot be changed — delete and recreate to switch.'
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :product_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[value],
        properties: { value: { description: 'New value' } }
      }

      response '200', 'custom field updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { value: 'cotton' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['value']).to eq('cotton')
        end
      end
    end

    delete 'Delete a product custom field' do
      tags 'Products'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :product_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'custom field deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do
          expect(Spree::CustomField.where(id: custom_field.id)).to be_empty
        end
      end
    end
  end
end
