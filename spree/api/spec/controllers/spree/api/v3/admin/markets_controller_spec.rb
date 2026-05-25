require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MarketsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:market) { create(:market, store: store) }
  let!(:other_store_market) { create(:market, store: create(:store)) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns markets in the current store only' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |m| m['id'] }
      expect(ids).to include(market.prefixed_id)
      expect(ids).not_to include(other_store_market.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns the market' do
      get :show, params: { id: market.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(market.prefixed_id)
      expect(json_response['name']).to eq(market.name)
    end

    it '404s on a market from another store' do
      get :show, params: { id: other_store_market.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
