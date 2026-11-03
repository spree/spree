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

      admin_sdk_example 'customer-tax-identifiers/list'

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

      admin_sdk_example 'customer-tax-identifiers/update'

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

  path '/api/v3/admin/customers/{customer_id}/tax_identifiers/{id}/validate' do
    let(:customer_id) { customer.prefixed_id }
    let(:id) { tax_identifier.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :customer_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    post 'Re-check a customer tax registration' do
      tags 'Customers'
      admin_sdk_example 'customer-tax-identifiers/validate'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Asks the registry again. Manual because a registry answers only "valid now" — a number verified
        last year may have been deregistered since — and because a check that came back unavailable
        cannot otherwise be retried without editing the number.
      DESC
      admin_scope :write, :customers

      response '202', 'registry check queued' do
        # Core ships no registry for eu_vat, so the spec installs the base
        # validator; the queued job is not performed here.
        around do |example|
          with_tax_identifier_validator('eu_vat', 'Spree::TaxIdentifiers::Validator::Base') { example.run }
        end

        schema '$ref' => '#/components/schemas/TaxIdentifier'

        run_test! do |response|
          expect(JSON.parse(response.body)['validation_status']).to eq('pending')
        end
      end

      response '422', 'no validator installed for this kind' do
        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['code']).to eq('tax_id_not_validatable')
        end
      end
    end
  end
end
