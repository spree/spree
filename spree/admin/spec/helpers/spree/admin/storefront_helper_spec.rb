# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Admin::StorefrontHelper, type: :helper do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, store: store) }

  describe '#vercel_deploy_url' do
    subject(:url) { helper.vercel_deploy_url(store, api_key) }

    let(:query) { Rack::Utils.parse_query(URI.parse(url).query) }

    it 'points at the Vercel clone flow for the storefront starter' do
      expect(url).to start_with('https://vercel.com/new/clone?')
      expect(query['repository-url']).to eq('https://github.com/spree/storefront')
      expect(query['project-name']).to eq("#{store.code}-storefront")
    end

    it 'requires and prefills the storefront environment variables' do
      expect(query['env']).to eq('SPREE_API_URL,SPREE_PUBLISHABLE_KEY')
      expect(JSON.parse(query['envDefaults'])).to eq(
        'SPREE_API_URL' => store.formatted_url,
        'SPREE_PUBLISHABLE_KEY' => api_key.token
      )
    end

    it 'redirects back to the admin storefront page' do
      expect(query['redirect-url']).to eq('http://test.host/admin/storefront')
    end
  end

  describe '#store_url_loopback?' do
    it 'is true for loopback store urls' do
      expect(helper.store_url_loopback?(build(:store, url: 'localhost:3000'))).to be true
    end

    it 'is false for public store urls' do
      expect(helper.store_url_loopback?(build(:store, url: 'shop.example.com'))).to be false
    end
  end
end
