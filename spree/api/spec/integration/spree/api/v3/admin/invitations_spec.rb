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
      admin_scope :read, :staff

      admin_sdk_example 'invitations/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

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
      admin_scope :write, :staff

      admin_sdk_example 'invitations/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      request_body_for

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
      admin_scope :write, :staff

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

  path '/api/v3/admin/invitations/{invitation_id}/acceptance_link' do
    let(:invitation_id) { invitation.prefixed_id }

    get 'Get an invitation acceptance link' do
      tags 'Staff'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the link the invitee opens to accept a pending invitation. The link carries the ' \
                  'invitation token, so it needs write access to staff and the right to grant the invitation\'s ' \
                  'role; invitation listings never include it.'
      admin_scope :write, :staff

      admin_sdk_example 'invitations/acceptance-link'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :invitation_id, in: :path, type: :string, required: true

      response '200', 'acceptance link found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema '$ref' => '#/components/schemas/InvitationAcceptanceLink'

        run_test! do |response|
          expect(JSON.parse(response.body)['acceptance_url']).to include('/accept-invitation/')
        end
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
      admin_scope :write, :staff

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

  path '/api/v3/admin/auth/invitations/{id}/accept' do
    parameter name: :id, in: :path, type: :string, description: 'Invitation ID from the emailed link'

    let(:staff_invitation) do
      create(:invitation, resource: store, role: admin_role, inviter: admin_user, email: 'newcomer@acme.test')
    end

    post 'Accept an invitation' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description <<~DESC
        Accepts a staff invitation and returns a signed-in admin session, so the
        new member lands in the dashboard rather than on a login form.

        Unauthenticated — the ID and token in the emailed link are the
        credential. The email is never taken from the request; it always comes
        from the invitation.

        `password` is required when no account exists for the invited address,
        in which case it sets one. When an account already exists, the same
        field is how the person proves the account is theirs.
      DESC

      parameter name: :token, in: :query, type: :string, required: true,
                description: 'The token from the emailed link'
      request_body_for

      response '200', 'invitation accepted, session issued' do
        let(:id) { staff_invitation.prefixed_id }
        let(:token) { staff_invitation.token }
        let(:body) do
          { password: 'password123', password_confirmation: 'password123', first_name: 'Robin', last_name: 'Ellis' }
        end

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']['email']).to eq('newcomer@acme.test')
          expect(staff_invitation.reload.status).to eq('accepted')
        end
      end

      response '404', 'wrong token, or an invitation that can no longer be accepted' do
        let(:id) { staff_invitation.prefixed_id }
        let(:token) { 'not-the-token' }
        let(:body) { { password: 'password123', password_confirmation: 'password123' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
