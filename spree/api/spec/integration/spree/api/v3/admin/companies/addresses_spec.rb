# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Company Addresses API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:company) { create(:company, store: store) }
  let!(:address) { create(:company_address, owner: company, label: 'Head office') }

  path '/api/v3/admin/companies/{company_id}/addresses' do
    let(:company_id) { company.prefixed_id }

    get 'List company addresses' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Returns the business's addresses: its sites, billing address and delivery points."
      admin_scope :read, :customers

      admin_sdk_example 'companies/addresses/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :company_id, in: :path, type: :string, required: true
      filter_parameters_for

      response '200', 'addresses found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Address')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(address.prefixed_id)
        end
      end
    end

    post 'Create a company address' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds an address to the business. Pass `default_billing: true` or `default_shipping: true` to make it the default of that kind.'
      admin_scope :write, :customers

      admin_sdk_example 'companies/addresses/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :company_id, in: :path, type: :string, required: true
      request_body_for

      response '201', 'address created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            company: 'Acme Wholesale', label: 'Warehouse',
            address1: '350 Fifth Avenue', city: 'New York', postal_code: '10118',
            country_code: address.country.iso, state_code: address.state.abbr, phone: '+12125551234',
            default_shipping: true
          }
        end

        schema '$ref' => '#/components/schemas/Address'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['label']).to eq('Warehouse')
          expect(company.reload.default_shipping_address&.prefixed_id).to eq(data['id'])
        end
      end
    end
  end

  path '/api/v3/admin/companies/{company_id}/addresses/{id}' do
    let(:company_id) { company.prefixed_id }
    let(:id) { address.prefixed_id }

    patch 'Update a company address' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Changes an address of the business. Pass `default_billing` or `default_shipping` to move that default to it, or `false` to give it up.'
      admin_scope :write, :customers

      admin_sdk_example 'companies/addresses/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :company_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      request_body_for

      response '200', 'address updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { label: 'Northern Warehouse', default_billing: true } }

        schema '$ref' => '#/components/schemas/Address'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['label']).to eq('Northern Warehouse')
          expect(company.reload.default_billing_address&.prefixed_id).to eq(data['id'])
        end
      end
    end
  end
end
