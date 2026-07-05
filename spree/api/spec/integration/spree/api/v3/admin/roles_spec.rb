# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Roles API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:admin_role) { Spree::Role.default_admin_role }

  path '/api/v3/admin/roles' do
    get 'List roles' do
      tags 'Staff'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the roles available for staff role pickers. Roles are global, not per-store.'
      admin_scope :read, :settings

      admin_sdk_example 'roles/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'roles found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].pluck('name')).to include('admin')
        end
      end
    end
  end
end
