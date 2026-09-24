require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Sellers::Invitations::AcceptanceLinksController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  let(:seller) { create(:seller, store: store) }
  let(:invitation) do
    create(:invitation, resource: seller, role: seller.default_user_role, inviter: admin_user)
  end

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    context 'with a key that can change sellers' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['write_sellers']) }
      let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

      it 'returns the link with its token' do
        get :show, params: { seller_id: seller.prefixed_id, invitation_id: invitation.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['acceptance_url']).to include(invitation.token)
      end
    end

    context 'with a key that can only read sellers' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['read_sellers']) }
      let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

      it 'is forbidden' do
        get :show, params: { seller_id: seller.prefixed_id, invitation_id: invitation.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.body).not_to include(invitation.token)
      end
    end
  end
end
