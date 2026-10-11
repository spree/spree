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
  end
end
