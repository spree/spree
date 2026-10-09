# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Company Invitations API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:company) { create(:company, store: store) }
  let!(:invitation) { create(:company_invitation, company: company, email: 'buyer@example.com') }

  path '/api/v3/admin/companies/{company_id}/invitations' do
    let(:company_id) { company.prefixed_id }

    get 'List company invitations' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the invitations into this business that are still waiting to be accepted.'
      admin_scope :read, :customers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :company_id, in: :path, type: :string, required: true
      filter_parameters_for

      response '200', 'invitations found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('CompanyInvitation')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(invitation.prefixed_id)
        end
      end
    end
  end
end
