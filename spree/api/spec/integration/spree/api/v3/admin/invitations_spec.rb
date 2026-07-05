# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Invitations API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:admin_role) { Spree::Role.default_admin_role }
  let!(:invitation) do
    create(:invitation, resource: store, role: admin_role, inviter: admin_user)
  end

  path '/api/v3/admin/invitations' do
    get 'List invitations' do
      tags 'Staff'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns invitations for the current store, including pending and accepted.'
      admin_scope :read, :settings

      admin_sdk_example 'invitations/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'invitations found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].pluck('id')).to include(invitation.prefixed_id)
        end
      end
    end

    post 'Create an invitation' do
      tags 'Staff'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Invites a teammate by email. The invitation is scoped to the current store and carries the chosen role; ' \
                  'on accept, a `RoleUser` is created via the invitation\'s `after_accept` callback.'
      admin_scope :write, :settings

      admin_sdk_example 'invitations/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[email role_id],
        properties: {
          email: { type: :string, example: 'ada@example.com' },
          role_id: { type: :string, example: 'role_xxx' }
        }
      }

      response '201', 'invitation created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { email: 'new-staff@example.com', role_id: admin_role.prefixed_id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('new-staff@example.com')
          expect(data['status']).to eq('pending')
          expect(data['role_name']).to eq('admin')
        end
      end
    end
  end

  path '/api/v3/admin/invitations/{id}' do
    let(:id) { invitation.prefixed_id }

    delete 'Revoke an invitation' do
      tags 'Staff'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :settings

      admin_sdk_example 'invitations/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'invitation revoked' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/invitations/{id}/resend' do
    let(:id) { invitation.prefixed_id }

    patch 'Resend an invitation' do
      tags 'Staff'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Issues a fresh token and dispatches the invitation email again.'
      admin_scope :write, :settings

      admin_sdk_example 'invitations/resend'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'invitation resent' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end
end
