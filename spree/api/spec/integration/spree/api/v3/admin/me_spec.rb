# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Me API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  path '/api/v3/admin/me' do
    get 'Get current admin user and permissions' do
      tags 'Authentication'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the current admin user profile and a serialized list of permissions (CanCanCan rules). The SPA uses these to drive UI permission checks.'

      admin_sdk_example <<~JS
        const me = await client.me.get()
        if (me.permissions.some((r) => r.allow && r.actions.includes('manage') && r.subjects.includes('Spree::Product'))) {
          // show "Create product" button
        }
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'current admin user and permissions' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:Authorization) { "Bearer #{admin_jwt_token}" }

        schema '$ref' => '#/components/schemas/MeResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user']).to be_present
          expect(data['user']['email']).to eq(admin_user.email)
          expect(data['permissions']).to be_an(Array)
          expect(data['permissions']).not_to be_empty
          expect(data['permissions'].first.keys).to match_array(%w[allow actions subjects has_conditions])
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
