# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Tax Categories API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:tax_category) { create(:tax_category, name: 'Clothing') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/tax_categories' do
    get 'List tax categories' do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the tax categories products and delivery methods can be assigned to, which tax rates then apply to.'
      admin_scope :read, :settings

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'tax categories found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('TaxCategory')

        run_test! do |response|
          ids = JSON.parse(response.body)['data'].map { |record| record['id'] }
          expect(ids).to include(tax_category.prefixed_id)
        end
      end
    end
  end
end
