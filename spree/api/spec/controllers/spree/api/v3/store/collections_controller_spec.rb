require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CollectionsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:collection) { create(:collection, store: store, name: 'Summer Sale') }
  let!(:other_store) { create(:store) }
  let!(:other_collection) { create(:collection, store: other_store) }

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  describe 'GET #index' do
    it 'returns collections for the current store only' do
      get :index

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].pluck('id')
      expect(ids).to include(collection.prefixed_id)
      expect(ids).not_to include(other_collection.prefixed_id)
    end

    it 'exposes customer-facing attributes but not the merchandising config' do
      get :index

      data = json_response['data'].find { |c| c['id'] == collection.prefixed_id }
      expect(data).to include('name', 'permalink', 'sort_order', 'products_count', 'description', 'image_url')
      expect(data).not_to include('automatic', 'rules_match_policy', 'rules')
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'finds by permalink' do
      get :show, params: { id: collection.permalink }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(collection.prefixed_id)
      expect(json_response['name']).to eq('Summer Sale')
    end

    it 'finds by prefixed id' do
      get :show, params: { id: collection.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(collection.prefixed_id)
    end

    it 'omits the merchandising config' do
      get :show, params: { id: collection.prefixed_id }

      expect(json_response).not_to include('automatic', 'rules_match_policy', 'rules')
    end

    it "returns not found for another store's collection" do
      get :show, params: { id: other_collection.permalink }

      expect(response).to have_http_status(:not_found)
    end
  end
end
