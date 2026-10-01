require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Invitations::AcceptanceLinksController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  let!(:admin_role) { Spree::Role.default_admin_role }
  let(:staff_role) { create(:role, name: 'staff', permissions: %w[read_orders], resource: store) }
  let(:invitation) { create(:invitation, resource: store, role: staff_role) }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    context 'as a super-admin' do
      let(:headers) { bearer_headers }

      it 'returns the link with its token' do
        get :show, params: { invitation_id: invitation.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['acceptance_url']).to include(invitation.token)
      end

      it 'does not find an invitation of another store' do
        other = create(:invitation, resource: create(:store))

        get :show, params: { invitation_id: other.prefixed_id }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    # Reading staff is not enough: the token creates the account and grants
    # the role, so it is authorized like sending the invitation.
    context 'with a secret key that can only read staff' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['read_staff']) }
      let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

      it 'is forbidden' do
        get :show, params: { invitation_id: invitation.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.body).not_to include(invitation.token)
      end
    end

    context 'as a non-admin staff member who can write staff' do
      let(:inviter_role) { create(:role, name: 'team_manager', permissions: %w[write_staff read_orders], resource: store) }
      let(:staff_admin) do
        create(:admin_user, :without_admin_role).tap { |user| create(:role_user, user: user, role: inviter_role) }
      end
      let(:headers) do
        { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staff_admin, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
      end

      it 'returns the link for a role it may grant' do
        get :show, params: { invitation_id: invitation.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
      end

      it 'is forbidden for an invitation into the admin role' do
        admin_invitation = create(:invitation, resource: store, role: admin_role)

        get :show, params: { invitation_id: admin_invitation.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.body).not_to include(admin_invitation.token)
      end
    end
  end
end
