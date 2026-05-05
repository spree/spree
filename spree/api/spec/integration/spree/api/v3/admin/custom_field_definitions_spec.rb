# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Custom Field Definitions API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product_definition) do
    create(:metafield_definition, :short_text_field, namespace: 'specs', key: 'fabric')
  end
  let!(:order_definition) do
    create(:metafield_definition, :for_order)
  end
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/custom_field_definitions' do
    get 'List custom field definitions' do
      tags 'Custom Fields'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all defined custom fields. Filter by `?q[resource_type_eq]=Spree::Product` to narrow to one parent type.'
      admin_scope :read, :custom_field_definitions

      admin_sdk_example <<~JS
        const { data: definitions } = await client.customFieldDefinitions.list({
          q: { resource_type_eq: 'Spree::Product' },
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand. Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., key,label,field_type). id is always included.'

      response '200', 'definitions returned' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to be >= 2
          item = data['data'].find { |d| d['key'] == 'fabric' }
          expect(item['namespace']).to eq('specs')
          expect(item['field_type']).to eq('short_text')
          expect(item['storefront_visible']).to eq(true)
          expect(item['resource_type']).to eq('Spree::Product')
        end
      end
    end

    post 'Create a custom field definition' do
      tags 'Custom Fields'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :custom_field_definitions

      admin_sdk_example <<~JS
        const definition = await client.customFieldDefinitions.create({
          namespace: 'specs',
          key: 'origin',
          label: 'Country of Origin',
          field_type: 'short_text',
          resource_type: 'Spree::Product',
          storefront_visible: true,
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[key field_type resource_type],
        properties: {
          namespace: { type: :string, description: 'Defaults to `custom`' },
          key: { type: :string },
          label: { type: :string, description: 'Human-readable name; defaults to titleized `key`' },
          field_type: {
            type: :string,
            description: 'Custom field type identifier (one of the registered field-type class names).'
          },
          resource_type: {
            type: :string,
            description: 'Owner class, e.g. `Spree::Product`'
          },
          storefront_visible: {
            type: :boolean,
            description: 'When false, definition is admin-only (was `display_on: back_end`)'
          }
        }
      }

      response '201', 'definition created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            namespace: 'specs',
            key: 'origin',
            label: 'Country of Origin',
            field_type: 'short_text',
            resource_type: 'Spree::Product',
            storefront_visible: true
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['key']).to eq('origin')
          expect(data['label']).to eq('Country of Origin')
          expect(data['field_type']).to eq('short_text')
          expect(data['storefront_visible']).to eq(true)
        end
      end
    end
  end

  path '/api/v3/admin/custom_field_definitions/{id}' do
    let(:id) { product_definition.prefixed_id }

    get 'Show a custom field definition' do
      tags 'Custom Fields'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :custom_field_definitions

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand. Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., key,label,field_type). id is always included.'

      response '200', 'definition found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(product_definition.prefixed_id)
          expect(data['key']).to eq('fabric')
        end
      end
    end

    patch 'Update a custom field definition' do
      tags 'Custom Fields'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :custom_field_definitions

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          label: { type: :string },
          storefront_visible: { type: :boolean }
        }
      }

      response '200', 'definition updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { label: 'Fabric Composition', storefront_visible: false } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['label']).to eq('Fabric Composition')
          expect(data['storefront_visible']).to eq(false)
        end
      end
    end

    delete 'Delete a custom field definition' do
      tags 'Custom Fields'
      security [api_key: [], bearer_auth: []]
      description 'Deletes the definition and cascades to all custom field values referencing it.'
      admin_scope :write, :custom_field_definitions

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'definition deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do
          expect(Spree::CustomFieldDefinition.where(id: product_definition.id)).to be_empty
        end
      end
    end
  end
end
