require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MediaSerializer do
  let(:store) { create(:store, url: 'store.example.com') }
  let(:product) { create(:product, store: store) }
  let(:image) { create(:image, viewable: product) }

  subject(:download_url) { described_class.new(image, params: { store: store }).to_h['download_url'] }

  describe 'download_url host resolution' do
    context 'when Spree.cdn_host is present' do
      before { allow(Spree).to receive(:cdn_host).and_return('cdn.example.com') }

      it 'uses the cdn host' do
        expect(download_url).to include('cdn.example.com')
      end
    end

    context 'when cdn_host is blank and a current store exists' do
      before do
        allow(Spree).to receive(:cdn_host).and_return(nil)
        allow(Spree::Store).to receive(:current).and_return(store)
      end

      it "prefers the store's formatted_url over default_url_options[:host]" do
        expect(download_url).to start_with(store.formatted_url)
      end
    end
  end
end
