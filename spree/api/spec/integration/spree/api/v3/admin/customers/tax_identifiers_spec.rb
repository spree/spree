# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Customer Tax Identifiers API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:customer) { create(:user) }
  let!(:tax_identifier) { create(:tax_identifier, owner: customer) }

  path '/api/v3/admin/customers/{customer_id}/tax_identifiers' do
    let(:customer_id) { customer.prefixed_id }

    get 'List customer tax registrations' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Returns the customer's own tax registrations, one per kind."
      admin_scope :read, :customers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      filter_parameters_for

      response '200', 'registrations found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('TaxIdentifier')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(tax_identifier.prefixed_id)
        end
      end
    end
  end
end
