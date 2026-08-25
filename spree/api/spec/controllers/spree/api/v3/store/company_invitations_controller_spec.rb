require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CompanyInvitationsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:company) { create(:company, store: store, name: 'Acme Industrial') }
  let!(:invitation) { create(:company_invitation, company: company, email: 'new@example.com') }

  describe 'GET #show (token lookup, unauthenticated)' do
    before { request.headers.merge!(api_key_headers) }

    it 'shows what is being joined' do
      get :show, params: { token: invitation.token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['email']).to eq('new@example.com')
      expect(json_response['company_name']).to eq('Acme Industrial')
      expect(json_response['store_name']).to eq(store.name)
      expect(json_response).not_to have_key('token')
    end

    it '404s an expired token' do
      invitation.update!(expires_at: 1.day.ago)

      get :show, params: { token: invitation.token }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '404s a revoked token' do
      invitation.revoke!

      get :show, params: { token: invitation.token }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '404s garbage' do
      get :show, params: { token: 'nope' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #accept' do
    context 'with a registration payload' do
      before { request.headers.merge!(api_key_headers) }

      it 'registers the invited email and lands as a membership' do
        post :accept, params: {
          token: invitation.token,
          first_name: 'Ada', password: 'Sup3r-secret', password_confirmation: 'Sup3r-secret'
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['id']).to start_with('cmem_')
        expect(json_response['email']).to eq('new@example.com')
        expect(invitation.reload).to be_accepted
      end

      it 'fails a bad registration and keeps the invitation pending' do
        post :accept, params: { token: invitation.token, password: 'x' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(invitation.reload).to be_pending
      end
    end

    context 'authenticated' do
      before { request.headers.merge!(bearer_headers) }

      it 'binds the invitation to the signed-in customer' do
        post :accept, params: { token: invitation.token }, as: :json

        expect(response).to have_http_status(:created)
        expect(invitation.reload.customer).to eq(user)
        expect(company.memberships.sole.customer).to eq(user)
      end
    end

    it '422s a spent token' do
      request.headers.merge!(api_key_headers)
      invitation.update!(accepted_at: Time.current)

      post :accept, params: { token: invitation.token }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy (revoke)' do
    it 'lets a member with standing revoke' do
      create(:company_membership, company: company, customer: user)
      request.headers.merge!(bearer_headers)

      delete :destroy, params: { id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(invitation.reload).to be_revoked
    end

    it '404s without standing' do
      request.headers.merge!(bearer_headers)

      delete :destroy, params: { id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '401s a guest' do
      request.headers.merge!(api_key_headers)

      delete :destroy, params: { id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
