require 'spec_helper'

describe 'cdn_image direct route', type: :routing do
  subject(:url) { Rails.application.routes.url_helpers.cdn_image_url(image.attachment) }

  let(:store) { create(:store, url: 'store.example.com') }
  let(:variant) { create(:variant) }
  let(:image) { create(:image, viewable: variant) }

  context 'when Spree.cdn_host is present' do
    before { allow(Spree).to receive(:cdn_host).and_return('cdn.example.com') }

    it 'uses the cdn host' do
      expect(url).to include('cdn.example.com')
    end
  end

  context 'when cdn_host is blank and a current store is present' do
    before do
      allow(Spree).to receive(:cdn_host).and_return(nil)
      allow(Spree::Store).to receive(:current).and_return(store)
    end

    it "falls back to the current store's formatted_url" do
      expect(url).to start_with(store.formatted_url)
    end
  end
end
