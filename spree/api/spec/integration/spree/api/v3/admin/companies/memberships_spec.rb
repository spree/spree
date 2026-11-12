# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Company Memberships API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:company) { create(:company, store: store) }

  path '/api/v3/admin/companies/{company_id}/memberships' do
    let(:company_id) { company.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :company_id, in: :path, type: :string, required: true

    get 'List company members' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the people with standing over this node. Standing covers the node and everything below it in the tree.'
      admin_scope :read, :customers

      admin_sdk_example 'companies/memberships/list'

      filter_parameters_for

      response '200', 'members found' do
        let!(:membership) { create(:company_membership, company: company) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(membership.prefixed_id)
        end
      end
    end

    post 'Add a member' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds a person to the node, either an existing customer by `customer_id` or anyone by
        `customer_email`. A customer, or an email matching one, becomes a membership immediately
        (a `cmem_…` id); an unknown email becomes an invitation (a `cinv_…` id) and the invite
        email goes out.
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'companies/memberships/create'

      request_body_for

      # Listed first: the last 201 example is the one the reference documents.
      response '201', 'existing customer added by id' do
        let!(:customer) { create(:customer, email: 'picked@example.com') }
        let(:body) { { customer_id: customer.prefixed_id } }

        run_test! do |response|
          expect(JSON.parse(response.body)['email']).to eq('picked@example.com')
        end
      end

      response '201', 'member added' do
        let!(:customer) { create(:customer, email: 'buyer@example.com') }
        let(:body) { { customer_email: 'buyer@example.com' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['email']).to eq('buyer@example.com')
        end
      end
    end
  end
end
