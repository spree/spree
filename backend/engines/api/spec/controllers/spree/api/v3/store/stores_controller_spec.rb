require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::StoresController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #current' do
    it 'returns the current store' do
      get :current

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(store.prefixed_id)
    end

    it 'returns store attributes' do
      get :current

      expect(json_response).to include('id', 'name', 'url', 'default_currency')
    end

    it 'returns store settings' do
      get :current

      expect(json_response['default_currency']).to eq(store.default_currency)
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :current

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
        expect(json_response['error']['message']).to be_present
      end
    end

    context 'with invalid API key' do
      before { request.headers['X-Spree-Api-Key'] = 'invalid' }

      it 'returns unauthorized' do
        get :current

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
      end
    end

    context 'with API key from different store' do
      let(:other_store) { create(:store) }
      let(:other_api_key) { create(:api_key, :publishable, store: other_store) }

      before { request.headers['X-Spree-Api-Key'] = other_api_key.token }

      it 'returns unauthorized as API keys are scoped to their store' do
        get :current

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('invalid_token')
      end
    end
  end
end
