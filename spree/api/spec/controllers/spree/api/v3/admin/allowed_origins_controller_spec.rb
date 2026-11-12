require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::AllowedOriginsController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  before { request.headers.merge!(api_key_headers) }

  # An allowed origin may call the cookie-authenticated refresh endpoint from
  # a browser and read back any admin's access token, so the list is managed
  # like a credential — a settings key must not be enough.
  describe 'POST #create' do
    subject { post :create, params: { origin: 'https://attacker.example' }, as: :json }

    context 'with a settings key' do
      let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: %w[write_settings]) }

      it 'is denied' do
        expect { subject }.not_to change(Spree::AllowedOrigin, :count)
        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['details']['required_scope']).to eq('write_api_keys')
      end
    end

    context 'with an api keys key' do
      let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: %w[write_api_keys]) }

      it 'creates the origin' do
        expect { subject }.to change(Spree::AllowedOrigin, :count).by(1)
        expect(response).to have_http_status(:created)
      end
    end
  end
end
