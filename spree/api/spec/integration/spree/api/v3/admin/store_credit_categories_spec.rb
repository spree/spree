# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Store Credit Categories API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:store_credit_category) { create(:store_credit_category, name: 'Goodwill') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/store_credit_categories' do
    get 'List store credit categories' do
      tags 'Configuration'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the configured store credit categories. Categories classify
        store credits (e.g., "Goodwill", "Gift Card", "Refund") and surface
        in the admin UI as a dropdown when issuing or editing a store
        credit. Category names matching `Spree::Config[:non_expiring_credit_types]`
        are flagged via `non_expiring: true`.
      DESC
      admin_scope :read, :settings

      admin_sdk_example <<~JS
        const { data: categories } = await client.storeCreditCategories.list()
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort by field. Prefix with `-` for descending (e.g., `-created_at`).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'store credit categories found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('StoreCreditCategory')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].map { |c| c['id'] }).to include(store_credit_category.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/store_credit_categories/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Store credit category ID'

    get 'Get a store credit category' do
      tags 'Configuration'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single store credit category by prefixed ID.'
      admin_scope :read, :settings

      admin_sdk_example <<~JS
        const category = await client.storeCreditCategories.get('sccat_UkLWZg9DAJ')
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'store credit category found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { store_credit_category.prefixed_id }

        schema '$ref' => '#/components/schemas/StoreCreditCategory'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(store_credit_category.prefixed_id)
          expect(data['name']).to eq('Goodwill')
          expect(data).to have_key('non_expiring')
        end
      end

      response '404', 'store credit category not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'sccat_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
