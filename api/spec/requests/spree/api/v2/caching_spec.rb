require 'spec_helper'

describe 'API v2 Caching spec', type: :request do
  include_context 'API v2 tokens'

  let!(:product) { create(:product, name: 'Some name', stores: [store]) }
  let(:store) { Spree::Store.default }

  before do
    store.update!(supported_currencies: 'USD,CAD')
    ActionController::Base.perform_caching = true
    Rails.cache.clear
  end

  after do
    ActionController::Base.perform_caching = false
    Rails.cache.clear
  end

  context 'collections caching' do
    let(:cache_namespace) { 'api_v2_collection_cache' }
    let!(:products) { create_list(:product_in_stock, 5, stores: [store]) }
    let(:user) { create(:user) }

    def cache_entries
      Rails.cache.instance_variable_get(:@data).keys.find_all { |k| k.start_with?(cache_namespace) }
    end

    before do
      products.each { |product| product.update_columns(updated_at: 1.day.ago, created_at: 1.day.ago) }
      products.last.update(name: 'Updated name')
    end

    it 'caches collection' do
      expect(cache_entries).to be_empty

      get '/api/v2/storefront/products'

      expect(cache_entries).not_to be_empty
      expect(cache_entries.size).to eq(1)

      get '/api/v2/storefront/products?include=variants'
      expect(cache_entries.size).to eq(2)

      get '/api/v2/storefront/products'
      expect(cache_entries.size).to eq(2)

      get '/api/v2/storefront/products?page=2'
      expect(cache_entries.size).to eq(3)

      get '/api/v2/storefront/products?page=2'
      expect(cache_entries.size).to eq(3)

      get '/api/v2/storefront/products?per_page=1'
      expect(cache_entries.size).to eq(4)

      get '/api/v2/storefront/products?per_page=1'
      expect(cache_entries.size).to eq(4)

      get '/api/v2/storefront/products?currency=CAD'
      expect(cache_entries.size).to eq(5)

      get '/api/v2/storefront/products?currency=CAD'
      expect(cache_entries.size).to eq(5)

      get '/api/v2/storefront/products?filter[name]=Updated'
      expect(cache_entries.size).to eq(6)

      get '/api/v2/storefront/products', headers: headers_bearer
      expect(cache_entries.size).to eq(7)
    end

    it 'auto expires cache', retry: 3 do
      get '/api/v2/storefront/products'
      expect(cache_entries.size).to eq(1)

      # expire all cache when store is updates
      store.update_column(:updated_at, 1.day.ago)

      get '/api/v2/storefront/products'
      expect(cache_entries.size).to eq(2)

      get '/api/v2/storefront/products'
      expect(cache_entries.size).to eq(2)

      # expire all cache when one of the related resources is updated
      products.last.update!(name: "new name #{rand(9999)}")

      get '/api/v2/storefront/products'
      expect(cache_entries.size).to eq(3)

      get '/api/v2/storefront/products'
      expect(cache_entries.size).to eq(3)
    end
  end

  context 'serialiers caching' do
    let(:cache_store) { Spree::V2::Storefront::ProductSerializer.cache_store_instance }
    let(:cache_entry) { cache_store.read(product, namespace: cache_namespace) }

    context 'auto expiration' do
      let(:cache_namespace) { "jsonapi-serializer-usd-en-#{store.cache_key_with_version}" }

      it 'auto expire cache after record being updated' do
        get "/api/v2/storefront/products/#{product.id}"

        expect(json_response['data']).to have_attribute('name').with_value('Some name')

        expect(cache_entry).not_to be_nil
        expect(cache_entry[:attributes].as_json).to eq(json_response[:data][:attributes])

        product.update(name: 'Something else')
        expect(cache_store.read(product, namespace: cache_namespace)).to be_nil

        get "/api/v2/storefront/products/#{product.id}"
        expect(cache_store.read(product, namespace: cache_namespace)).not_to be_nil
        expect(json_response['data']).to have_attribute('name').with_value('Something else')
      end
    end

    context 'currency and user' do
      include_context 'API v2 tokens'

      before { store.update!(supported_currencies: 'USD,EUR', supported_locales: 'en,de') }

      let!(:user) { create(:user) }
      let(:currency) { 'EUR' }
      let(:locale) { 'de' }
      let(:cache_namespace) { "jsonapi-serializer-eur-de-#{store.cache_key_with_version}-#{user.cache_key_with_version}" }

      it 'includes currency and signed user in the cache key' do
        get "/api/v2/storefront/products/#{product.id}?currency=#{currency}&locale=#{locale}", headers: headers_bearer

        expect(cache_entry).not_to be_nil
      end
    end
  end
end
