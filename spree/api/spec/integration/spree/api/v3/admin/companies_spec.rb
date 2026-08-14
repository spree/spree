# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Companies API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  let!(:company) { create(:company, store: store, name: 'Acme Industrial', external_id: 'ACME-1') }

  path '/api/v3/admin/companies' do
    get 'List companies' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the business customers of the current store.'
      admin_scope :read, :customers

      admin_sdk_example 'companies/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'companies found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(company.prefixed_id)
        end
      end
    end

    post 'Create a company' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a business customer. Exemption certificates and tax registrations hang off it.'
      admin_scope :write, :customers

      admin_sdk_example 'companies/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Globex Corporation' },
          external_id: { type: :string, nullable: true,
                         description: 'Your own reference for this business, unique within the store.',
                         example: 'GLBX-42' }
        },
        required: ['name']
      }

      let(:'x-spree-api-key') { secret_api_key.plaintext_token }

      response '201', 'company created' do
        let(:body) { { name: 'Globex Corporation', external_id: 'GLBX-42' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Globex Corporation')
        end
      end

      response '422', 'invalid request' do
        let(:body) { { external_id: 'NO-NAME' } }

        run_test!
      end
    end
  end
end
