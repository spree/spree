require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::InvitationAcceptancesController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  let(:role) { Spree::Role.default_admin_role }
  let!(:inviter) { create(:admin_user) }
  let(:invitation_email) { 'invitee@example.com' }

  # The "set_invitee_from_email" before_validation callback only runs on
  # create — fine for our tests since the controller resolves invitee
  # itself at accept-time. `inviter` is `let!` so its row already exists
  # before any `expect { ... }.to change(AdminUser, :count)` block runs.
  let!(:invitation) do
    create(:invitation, email: invitation_email, resource: store, role: role, inviter: inviter)
  end

  describe 'GET #lookup' do
    context 'with a valid prefixed ID + token' do
      it 'returns the safe invitation context' do
        get :lookup, params: { id: invitation.prefixed_id, token: invitation.token }

        expect(response).to have_http_status(:ok)
        expect(json_response['email']).to eq(invitation_email)
        expect(json_response['role_name']).to eq(role.name)
        expect(json_response['inviter_email']).to eq(inviter.email)
        expect(json_response['invitee_exists']).to eq(false)
        expect(json_response['store']['name']).to eq(store.name)
      end

      it 'reports invitee_exists when an admin user with that email already exists' do
        create(:admin_user, :without_admin_role, email: invitation_email)
        get :lookup, params: { id: invitation.prefixed_id, token: invitation.token }

        expect(json_response['invitee_exists']).to eq(true)
      end
    end

    context 'with a wrong token' do
      it 'returns 404' do
        get :lookup, params: { id: invitation.prefixed_id, token: 'bogus' }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the invitation has expired' do
      it 'returns 404' do
        invitation.update_columns(expires_at: 1.day.ago)
        get :lookup, params: { id: invitation.prefixed_id, token: invitation.token }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #accept' do
    context 'when the invitee already has an account' do
      let!(:existing) do
        create(:admin_user, :without_admin_role, email: invitation_email,
                            password: 'password123', password_confirmation: 'password123')
      end

      it 'verifies the password, accepts, and issues a JWT' do
        post :accept,
             params: { id: invitation.prefixed_id, token: invitation.token, password: 'password123' }

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['user']['email']).to eq(invitation_email)
        expect(invitation.reload.status).to eq('accepted')
        expect(invitation.reload.invitee_id).to eq(existing.id)
      end

      it 'rejects an invalid password without accepting the invitation' do
        post :accept,
             params: { id: invitation.prefixed_id, token: invitation.token, password: 'wrong' }

        expect(response).to have_http_status(:unauthorized)
        expect(invitation.reload.status).to eq('pending')
      end
    end

    context 'when the invitee does not yet have an account' do
      it 'creates the user, accepts the invitation, and issues a JWT' do
        expect {
          post :accept, params: {
            id: invitation.prefixed_id,
            token: invitation.token,
            password: 'password123',
            password_confirmation: 'password123',
            first_name: 'Pat',
            last_name: 'Carlson'
          }
        }.to change(Spree.admin_user_class, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['user']['email']).to eq(invitation_email)

        new_user = Spree.admin_user_class.find_by(email: invitation_email)
        expect(new_user.first_name).to eq('Pat')
        expect(invitation.reload.status).to eq('accepted')
        expect(invitation.reload.invitee_id).to eq(new_user.id)
      end

      it 'returns a validation error when password is missing' do
        post :accept,
             params: { id: invitation.prefixed_id, token: invitation.token, first_name: 'Pat' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(invitation.reload.status).to eq('pending')
      end
    end

    context 'with a wrong token' do
      it 'returns 404 without touching the invitation' do
        post :accept,
             params: { id: invitation.prefixed_id, token: 'bogus', password: 'whatever' }

        expect(response).to have_http_status(:not_found)
        expect(invitation.reload.status).to eq('pending')
      end
    end
  end
end
