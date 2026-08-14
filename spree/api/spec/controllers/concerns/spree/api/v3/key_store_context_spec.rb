require 'spec_helper'

# Covers KeyStoreContext using CountriesController as a representative Store
# API controller. Deliberately does NOT use the 'API v3 Store' shared context
# — that stubs +current_store+, which is the mechanic under test here.
RSpec.describe Spree::Api::V3::Store::CountriesController, type: :controller do
  render_views

  let(:other_store) { create(:store) }

  context 'with a publishable key of a non-default store' do
    let(:api_key) { create(:api_key, :publishable, store: other_store) }

    before { request.headers['X-Spree-Api-Key'] = api_key.token }

    it "resolves the key's store, never the host or the default store" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(controller.send(:current_store)).to eq(other_store)
    end
  end

  context 'without a key' do
    it 'returns 401, not 404 from the store-presence guard' do
      get :index, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'with an unknown key' do
    before { request.headers['X-Spree-Api-Key'] = 'pk_does_not_exist' }

    it 'returns 401' do
      get :index, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'with a revoked key' do
    let(:api_key) { create(:api_key, :publishable, store: other_store, revoked_at: 1.day.ago) }

    before { request.headers['X-Spree-Api-Key'] = api_key.token }

    it 'returns 401' do
      get :index, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
