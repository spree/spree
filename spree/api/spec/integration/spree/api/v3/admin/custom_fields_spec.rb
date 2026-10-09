# frozen_string_literal: true

require 'swagger_helper'

# Product custom fields have their own spec (admin/products/custom_fields_spec.rb)
# with the write operations; these are the lists on every other parent.
RSpec.describe 'Admin Custom Fields API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  {
    'categories' => { tag: 'Categories', scope: :categories, label: 'category', parent: -> { create(:category) } },
    'collections' => { tag: 'Collections', scope: :collections, label: 'collection', parent: -> { create(:collection, store: store) } },
    'customers' => { tag: 'Customers', scope: :customers, label: 'customer', parent: -> { create(:user) } },
    'option_types' => { tag: 'Option Types', scope: :products, label: 'option type', parent: -> { create(:option_type) } },
    'orders' => { tag: 'Orders', scope: :orders, label: 'order', parent: -> { create(:order, store: store) } },
    'sellers' => { tag: 'Sellers', scope: :sellers, label: 'seller', parent: -> { create(:seller, store: store) } },
    'variants' => { tag: 'Variants', scope: :products, label: 'variant', parent: -> { create(:variant) } }
  }.each do |segment, config|
    parent_param = :"#{segment.singularize}_id"

    path "/api/v3/admin/#{segment}/{#{parent_param}}/custom_fields" do
      get "List #{config[:label]} custom fields" do
        tags config[:tag]
        produces 'application/json'
        security [api_key: [], bearer_auth: []]
        description "Returns the #{config[:label]}'s custom field values."
        admin_scope :read, config[:scope]

        parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
        parameter name: :Authorization, in: :header, type: :string, required: true
        parameter name: parent_param, in: :path, type: :string, required: true
        parameter name: :expand, in: :query, type: :string, required: false,
                  description: 'Comma-separated associations to expand (e.g., custom_field_definition). Use dot notation for nested expand (max 4 levels).'
        parameter name: :fields, in: :query, type: :string, required: false,
                  description: 'Comma-separated list of fields to include (e.g., key,value,namespace). id is always included.'
        filter_parameters_for

        response '200', 'custom fields found' do
          let(:'x-spree-api-key') { secret_api_key.plaintext_token }
          let(:parent) { instance_exec(&config[:parent]) }
          let(:definition) do
            create(:custom_field_definition, :short_text_field, resource_type: parent.class.name)
          end
          let!(:custom_field) do
            create(:custom_field, resource: parent, custom_field_definition: definition, value: 'wool')
          end
          let(parent_param) { parent.prefixed_id }

          schema SwaggerSchemaHelpers.paginated('CustomField')

          run_test! do |response|
            data = JSON.parse(response.body)['data']
            expect(data.map { |record| record['id'] }).to eq([custom_field.prefixed_id])
          end
        end
      end
    end
  end
end
