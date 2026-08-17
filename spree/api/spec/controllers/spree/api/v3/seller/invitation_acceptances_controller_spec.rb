require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::InvitationAcceptancesController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:inviter) { create(:admin_user) }
  let(:invitation) do
    create(:invitation, resource: seller, inviter: inviter, email: 'newcomer@example.com')
  end

  describe 'GET #lookup' do
    it 'describes the invitation to someone holding the token' do
      get :lookup, params: { id: invitation.prefixed_id, token: invitation.token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['email']).to eq('newcomer@example.com')
    end

    it 'refuses a wrong token' do
      get :lookup, params: { id: invitation.prefixed_id, token: 'wrong' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    # The seller panel must not become a way to accept a staff invitation:
    # that carries no seller membership, so it would mint a seller token for
    # someone who runs no seller.
    it 'refuses an invitation onto the store' do
      staff = create(:invitation, resource: store, inviter: inviter)

      get :lookup, params: { id: staff.prefixed_id, token: staff.token }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #accept' do
    it 'creates the account and signs them in as a seller' do
      post :accept,
           params: {
             id: invitation.prefixed_id, token: invitation.token,
             password: 'sekrit123', password_confirmation: 'sekrit123',
             first_name: 'New', last_name: 'Comer'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['user']['email']).to eq('newcomer@example.com')
      expect(json_response['sellers'].pluck('id')).to eq([seller.prefixed_id])
      expect(invitation.reload).to be_accepted
    end

    # The whole point of the branch: the token this endpoint issues is a
    # seller token, so the panel it lands on can actually use it.
    it 'issues a seller-audience token' do
      post :accept,
           params: {
             id: invitation.prefixed_id, token: invitation.token,
             password: 'sekrit123', password_confirmation: 'sekrit123'
           },
           as: :json

      payload = JWT.decode(
        json_response['token'], Rails.application.secret_key_base, true, algorithm: 'HS256'
      ).first

      expect(payload['aud']).to eq(Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER)
    end

    it 'requires a password when the account does not exist yet' do
      post :accept, params: { id: invitation.prefixed_id, token: invitation.token }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(invitation.reload).not_to be_accepted
    end

    context 'when the invitee already has an account' do
      let!(:existing) { create(:admin_user, email: 'newcomer@example.com', password: 'sekrit123') }

      it 'signs them in with their existing password' do
        post :accept,
             params: { id: invitation.prefixed_id, token: invitation.token, password: 'sekrit123' },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(seller.reload.users).to include(existing)
      end

      it 'refuses a wrong password' do
        post :accept,
             params: { id: invitation.prefixed_id, token: invitation.token, password: 'nope' },
             as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(invitation.reload).not_to be_accepted
      end
    end

    it 'refuses an invitation onto the store' do
      staff = create(:invitation, resource: store, inviter: inviter)

      post :accept,
           params: { id: staff.prefixed_id, token: staff.token, password: 'sekrit123' },
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(staff.reload).not_to be_accepted
    end
  end
end
