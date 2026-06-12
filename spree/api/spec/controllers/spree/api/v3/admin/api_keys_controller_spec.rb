require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ApiKeysController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  before { request.headers.merge!(headers) }

  describe 'POST #create — scope amplification guard' do
    # Authenticate as a secret key holding only `write_settings` so the
    # request passes the scope check for the `:settings`-scoped controller
    # but is bounded by what that key actually holds.
    let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['write_settings']) }
    let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

    it 'rejects minting a key with scopes beyond the caller\'s own' do
      expect {
        post :create, params: { name: 'escalated', key_type: 'secret', scopes: ['write_all'] }, as: :json
      }.not_to change { Spree::ApiKey.secret.count }

      expect(response).to have_http_status(:forbidden)
      expect(json_response['error']['details']['excess_scopes']).to include('write_all')
    end

    it 'allows minting a key with scopes the caller already holds' do
      post :create, params: { name: 'sibling', key_type: 'secret', scopes: ['write_settings'] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['scopes']).to eq(['write_settings'])
    end

    it 'allows the implied read scope of a held write scope' do
      post :create, params: { name: 'reader', key_type: 'secret', scopes: ['read_settings'] }, as: :json

      expect(response).to have_http_status(:created)
    end

    context 'when the caller holds write_all' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }

      it 'may mint any scope' do
        post :create, params: { name: 'broad', key_type: 'secret', scopes: ['write_orders'] }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['scopes']).to eq(['write_orders'])
      end
    end

    context 'when authenticated as a JWT admin (super-user)' do
      let(:headers) { bearer_headers }

      it 'may grant any valid scope (bounded by CanCanCan, not scopes)' do
        post :create, params: { name: 'jwt-minted', key_type: 'secret', scopes: ['write_all'] }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['scopes']).to eq(['write_all'])
      end
    end
  end
end
