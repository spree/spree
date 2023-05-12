require 'spec_helper'

describe 'Data Feeds API Google Feed', type: :request do
  subject { get '/api/v2/data_feeds/google/test-feed.rss' }

  context 'when a feed with given permalink does not exist' do
    before { subject }

    it_behaves_like 'returns 404 HTTP status'
  end

  context 'when there is a feed with a given slug' do
    before do
     create(:google_data_feed, store: Spree::Store.default, slug: 'test-feed', active: active)
     subject
   end

    context 'when the feed is active' do
      let(:active) { true }

      it_behaves_like 'returns 200 HTTP status'
    end

    context 'when the feed is not active' do
      let(:active) { false }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
