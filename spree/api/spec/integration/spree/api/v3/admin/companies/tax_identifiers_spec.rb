# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Company Tax Identifiers API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:company) { create(:company, store: store) }
  let!(:tax_identifier) do
    create(:tax_identifier, customer: nil, company: company, kind: 'eu_vat', value: 'DE123456789')
  end

  path '/api/v3/admin/companies/{company_id}/tax_identifiers' do
    let(:company_id) { company.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :company_id, in: :path, type: :string, required: true

    get 'List company tax registrations' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the business's tax registrations, one per kind. A business registration takes precedence
        over the buyer's own when a sale is for that business, because the invoice is addressed to the
        entity rather than the person who placed the order.
      DESC
      admin_scope :read, :customers

      response '200', 'registrations found' do
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('value')).to include('DE123456789')
        end
      end
    end

    post 'Create a company tax registration' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Registers a tax number against the business. Verification against the relevant registry runs in
        the background where a validator is installed for the kind; a stock installation registers none,
        leaving the status unattempted.
      DESC
      admin_scope :write, :customers

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          kind: { type: :string, description: 'The regime the number belongs to.', example: 'gb_vat' },
          value: { type: :string, example: 'GB123456789' }
        },
        required: %w[kind value]
      }

      response '201', 'registration created' do
        let(:body) { { kind: 'gb_vat', value: 'GB123456789' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['value']).to eq('GB123456789')
        end
      end

      response '422', 'invalid request' do
        # One registration per kind.
        let(:body) { { kind: 'eu_vat', value: 'DE999999999' } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/companies/{company_id}/tax_identifiers/{id}/validate' do
    let(:company_id) { company.prefixed_id }
    let(:id) { tax_identifier.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :company_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    post 'Re-check a company tax registration' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Asks the registry again. Manual because a registry answers only "valid now" — a number verified
        last year may have been deregistered since — and because a check that came back unavailable
        cannot otherwise be retried without editing the number.
      DESC
      admin_scope :write, :customers

      response '422', 'no validator installed for this kind' do
        run_test! do |response|
          expect(JSON.parse(response.body)['error']['code']).to eq('tax_id_not_validatable')
        end
      end
    end
  end
end
