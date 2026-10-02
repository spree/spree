# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Tax Categories API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:tax_category) { create(:tax_category, store: store, name: 'Clothing', tax_code: 'PC040100') }

  path '/api/v3/admin/tax_categories' do
    get 'List tax categories' do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the store's tax categories. A category groups products that are
        taxed alike (clothing, food, digital goods); tax rates then say what
        each category is charged in each jurisdiction. Products without a
        category fall back to the store's default one.
      DESC
      admin_scope :read, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[name_cont]', in: :query, type: :string, required: false,
                description: 'Filter by name (contains)'

      response '200', 'tax categories found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('TaxCategory')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |row| row['id'] }).to include(tax_category.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a tax category' do
      tags 'Settings'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a tax category to this store. Names are unique per store, ignoring case.'
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[name],
        properties: {
          name: { type: :string, example: 'Food' },
          tax_code: { type: :string, nullable: true, example: 'PF050001',
                      description: 'Product tax code an external tax provider classifies these products by.' },
          description: { type: :string, nullable: true },
          is_default: { type: :boolean, description: 'Setting to true demotes the previous default.' }
        }
      }

      response '201', 'tax category created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Food', tax_code: 'PF050001', is_default: true } }

        schema '$ref' => '#/components/schemas/TaxCategory'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Food')
          expect(data['is_default']).to be(true)
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

  path '/api/v3/admin/tax_categories/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Tax category ID'

    patch 'Update a tax category' do
      tags 'Settings'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          tax_code: { type: :string, nullable: true },
          description: { type: :string, nullable: true },
          is_default: { type: :boolean, description: 'Setting to true demotes the previous default.' }
        }
      }

      response '200', 'tax category updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { tax_category.prefixed_id }
        let(:body) { { name: 'Apparel', tax_code: 'PC040000' } }

        schema '$ref' => '#/components/schemas/TaxCategory'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Apparel')
          expect(data['tax_code']).to eq('PC040000')
        end
      end
    end
  end
end
