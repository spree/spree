require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ApiKeysController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  before { request.headers.merge!(headers) }

  describe 'POST #create — scope amplification guard' do
    # Authenticate as a secret key holding only `write_api_keys` so the
    # request passes the scope check for the `:api_keys`-scoped controller
    # but is bounded by what that key actually holds.
    let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['write_api_keys']) }
    let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

    it 'rejects minting a key with scopes beyond the caller\'s own' do
      expect {
        post :create, params: { name: 'escalated', key_type: 'secret', scopes: ['write_all'] }, as: :json
      }.not_to change { Spree::ApiKey.secret.count }

      expect(response).to have_http_status(:forbidden)
      expect(json_response['error']['details']['excess_scopes']).to include('write_all')
    end

    it 'allows minting a key with scopes the caller already holds' do
      post :create, params: { name: 'sibling', key_type: 'secret', scopes: ['write_api_keys'] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['scopes']).to eq(['write_api_keys'])
    end

    it 'allows the implied read scope of a held write scope' do
      post :create, params: { name: 'reader', key_type: 'secret', scopes: ['read_api_keys'] }, as: :json

      expect(response).to have_http_status(:created)
    end

    context 'when the caller holds only write_settings' do
      # Key management no longer rides the settings scope — a settings key
      # cannot mint, revoke, or destroy credentials.
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['write_settings']) }

      it 'is denied with the api_keys required_scope' do
        post :create, params: { name: 'nope', key_type: 'secret', scopes: ['read_orders'] }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['details']['required_scope']).to eq('write_api_keys')
      end
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

  describe 'GET #current' do
    # A read-only key that does NOT hold read_api_keys — introspecting the
    # key you authenticated with must work regardless of the api_keys scope.
    let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['read_orders']) }
    let(:headers) { { 'x-spree-api-key' => caller_key.plaintext_token } }

    it 'returns the authenticating key with its live scopes' do
      get :current, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['token_prefix']).to eq(caller_key.token_prefix)
      expect(json_response['scopes']).to eq(['read_orders'])
    end

    it 'reflects a server-side scope change (no read_api_keys needed)' do
      caller_key.update_column(:scopes, %w[read_orders write_products])

      get :current, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['scopes']).to eq(%w[read_orders write_products])
    end

    context 'when authenticated as a JWT admin (no single key)' do
      let(:headers) { { 'Authorization' => "Bearer #{admin_jwt_token}" } }

      it 'returns 404 — a JWT principal has no single key to describe' do
        get :current, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #update' do
    let(:headers) { bearer_headers }
    let(:key) { create(:api_key, :secret, store: store, scopes: ['read_orders']) }

    it 'renames the key' do
      patch :update, params: { id: key.prefixed_id, name: 'Renamed key' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(key.reload.name).to eq('Renamed key')
    end

    it 'ignores scopes — they are fixed for the life of a key' do
      patch :update, params: { id: key.prefixed_id, name: 'Still read-only', scopes: ['write_all'] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(key.reload.scopes).to eq(['read_orders'])
      expect(key.name).to eq('Still read-only')
    end

    it 'ignores key_type' do
      patch :update, params: { id: key.prefixed_id, name: 'No flip', key_type: 'publishable' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(key.reload.key_type).to eq('secret')
    end
  end
end
