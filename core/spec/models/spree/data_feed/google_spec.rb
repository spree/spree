require 'spec_helper'

describe Spree::DataFeed::Google, type: :model do
  let(:store) { create(:store, url: 'http://store.test') }

  describe '#create' do
    context 'when slug is not provided' do
      let(:data_feed) { create(:google_data_feed, store: store, slug: nil) }

      it 'generates slug automatically' do
        expect(data_feed.slug).not_to be_empty
      end
    end

    context 'when slug is provided' do
      let(:data_feed) { create(:google_data_feed, store: store, slug: 'test-slug') }

      it 'uses the slug provided' do
        expect(data_feed.slug).to eq('test-slug')
      end
    end
  end

  describe '#formatted_url' do
    let(:data_feed) { create(:google_data_feed, store: store, slug: 'test-feed') }
    let(:expected_url) { 'http://store.test/api/v2/data_feeds/google/test-feed.rss' }

    it 'returns full url to the data feed' do
      expect(data_feed.formatted_url).to eq(expected_url)
    end
  end

  describe '.label' do
    subject { Spree::DataFeed::Google.label }

    it 'returns a descriptive label' do
      expect(subject).to eq('Google Merchant Center Feed')
    end
  end
end
