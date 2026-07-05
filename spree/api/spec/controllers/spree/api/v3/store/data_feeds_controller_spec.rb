require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::DataFeedsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:data_feed) { create(:google_data_feed, store: store, slug: 'test-feed') }

  describe 'GET #show' do
    it 'returns the feed XML without authentication' do
      get :show, params: { slug: 'test-feed' }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/xml')
      expect(response.body).to include('<rss')
      expect(response.body).to include(store.name)
    end

    context 'when data feed is inactive' do
      let!(:data_feed) { create(:google_data_feed, store: store, slug: 'inactive-feed', active: false) }

      it 'returns 404' do
        get :show, params: { slug: 'inactive-feed' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when data feed does not exist' do
      it 'returns 404' do
        get :show, params: { slug: 'nonexistent' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
