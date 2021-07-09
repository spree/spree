require 'spec_helper'

describe 'API v2 Store Switching spec', type: :request do
  let!(:store) { Spree::Store.default }
  let!(:another_store) { create(:store, url: 'another-store.lvh.me', name: 'Another Store') }

  let!(:product) { create(:product, stores: [store]) }
  let!(:another_product) { create(:product, stores: [another_store]) }

  context 'existing store found' do
    before { host!('another-store.lvh.me') }

    context 'product associated with store' do
      before { get "/api/v2/storefront/products/#{another_product.slug}" }

      it_behaves_like 'returns 200 HTTP status'
    end

    context 'product not associated with store' do
      before { get "/api/v2/storefront/products/#{product.slug}" }

      it_behaves_like 'returns 404 HTTP status'
    end
  end

  context 'non-existing store' do
    before { host!('missing-store.lvh.me') }

    context 'fallbacks to the default store' do
      context 'product associated with store' do
        before { get "/api/v2/storefront/products/#{product.slug}" }

        it_behaves_like 'returns 200 HTTP status'
      end

      context 'product not associated with store' do
        before { get "/api/v2/storefront/products/#{another_product.slug}" }

        it_behaves_like 'returns 404 HTTP status'
      end
    end
  end
end
