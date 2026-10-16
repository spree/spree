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

  path '/api/v3/admin/customers/{customer_id}/tax_identifiers/{id}' do
    let(:customer_id) { customer.prefixed_id }
    let(:id) { tax_identifier.prefixed_id }

    patch 'Update a customer tax registration' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Corrects a registration number. A changed number is checked again before it counts as verified.'
      admin_scope :write, :customers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :customer_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      request_body_for

      response '200', 'registration updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:new_value) { (TaxIdentifierValidatorHelpers.eu_vat_numbers - [tax_identifier.value]).first }
        let(:body) { { value: new_value } }

        schema '$ref' => '#/components/schemas/TaxIdentifier'

        run_test! do |response|
          expect(JSON.parse(response.body)['value']).to eq(new_value)
        end
      end
    end
  end
end
