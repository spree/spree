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
      filter_parameters_for

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
      description 'Creates a company node. A root node is a legal entity; pass parent_id and kind to build the organization tree. Exemption certificates and tax registrations hang off legal-entity nodes.'
      admin_scope :write, :customers

      admin_sdk_example 'companies/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

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

  path '/api/v3/admin/companies/{id}' do
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Update a company' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a company node. Only the attributes sent change.'
      admin_scope :write, :customers

      admin_sdk_example 'companies/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

      response '200', 'company updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { company.prefixed_id }
        let(:body) { { name: 'Acme Industrial Group', po_number_required: true } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Acme Industrial Group')
          expect(data['po_number_required']).to be(true)
        end
      end
    end
  end
end
