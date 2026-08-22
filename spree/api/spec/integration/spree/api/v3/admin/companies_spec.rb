# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Companies API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  let!(:company) do
    create(:company, store: store, name: 'Acme Industrial').tap { |record| record.set_external_id('erp', 'ACME-1') }
  end

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
          external_references: {
            type: :array,
            description: 'Identities this business has in your own systems. A system you do ' \
                         'not name keeps the reference it already has, and creating with a ' \
                         'reference that already exists updates that business instead.',
            items: {
              type: :object,
              properties: {
                system: { type: :string, example: 'erp' },
                external_id: { type: :string, example: 'GLBX-42' }
              },
              required: %w[system external_id]
            }
          }
        },
        required: ['name']
      }

      let(:'x-spree-api-key') { secret_api_key.plaintext_token }

      response '201', 'company created' do
        let(:body) do
          { name: 'Globex Corporation', external_references: [{ system: 'erp', external_id: 'GLBX-42' }] }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Globex Corporation')
        end
      end

      response '422', 'invalid request' do
        let(:body) { { external_references: [{ system: 'erp', external_id: 'NO-NAME' }] } }

        run_test!
      end
    end
  end
end
