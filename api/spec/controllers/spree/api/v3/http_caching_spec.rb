require 'spec_helper'

class HttpCachingTestController < ActionController::API
  include Spree::Api::V3::HttpCaching

  attr_accessor :current_user, :_current_currency, :_current_locale

  def current_currency
    _current_currency || 'USD'
  end

  def current_locale
    _current_locale || 'en'
  end
end

describe Spree::Api::V3::HttpCaching, type: :controller do
  let(:controller) { HttpCachingTestController.new }
  let(:request) { ActionDispatch::Request.new({}) }
  let(:response) { ActionDispatch::Response.new }

  before do
    allow(controller).to receive(:request).and_return(request)
    allow(controller).to receive(:response).and_return(response)
    allow(controller).to receive(:params).and_return(ActionController::Parameters.new(params))
    # Stub expires_in to set Cache-Control header directly
    allow(controller).to receive(:expires_in) do |duration, options = {}|
      parts = []
      parts << 'public' if options[:public]
      parts << "max-age=#{duration.to_i}"
      parts << "stale-while-revalidate=#{options[:stale_while_revalidate].to_i}" if options[:stale_while_revalidate]
      response.headers['Cache-Control'] = parts.join(', ')
    end
  end

  let(:params) { {} }

  describe '#guest_user?' do
    context 'when current_user is nil' do
      before { controller.current_user = nil }

      it 'returns true' do
        expect(controller.send(:guest_user?)).to be true
      end
    end

    context 'when current_user is present' do
      let(:user) { create(:user) }

      before { controller.current_user = user }

      it 'returns false' do
        expect(controller.send(:guest_user?)).to be false
      end
    end
  end

  describe '#set_vary_headers' do
    context 'for guest users' do
      before { controller.current_user = nil }

      it 'sets Vary header with Accept, X-Spree-Currency, X-Spree-Locale' do
        controller.send(:set_vary_headers)
        expect(response.headers['Vary']).to eq('Accept, X-Spree-Currency, X-Spree-Locale')
      end

      it 'does not set Cache-Control to private' do
        controller.send(:set_vary_headers)
        cache_control = response.headers['Cache-Control']
        expect(cache_control.nil? || !cache_control.include?('private')).to be true
      end
    end

    context 'for authenticated users' do
      let(:user) { create(:user) }

      before { controller.current_user = user }

      it 'sets Cache-Control to private, no-store' do
        controller.send(:set_vary_headers)
        expect(response.headers['Cache-Control']).to eq('private, no-store')
      end
    end
  end

  describe '#cache_collection' do
    let(:store) { @default_store }
    let!(:products) { create_list(:product, 3, stores: [store]) }
    let(:collection) { Spree::Product.where(id: products.map(&:id)) }

    context 'for guest users' do
      before do
        controller.current_user = nil
        allow(request).to receive(:fresh?).and_return(false)
      end

      it 'returns true to render response' do
        result = controller.send(:cache_collection, collection)
        expect(result).to be true
      end

      it 'sets ETag header' do
        controller.send(:cache_collection, collection)
        expect(response.headers['ETag']).to be_present
        expect(response.headers['ETag']).to match(/^"[a-f0-9]{32}"$/)
      end

      it 'sets Cache-Control with public, max-age and stale-while-revalidate' do
        controller.send(:cache_collection, collection)
        cache_control = response.headers['Cache-Control']
        expect(cache_control).to include('public')
        expect(cache_control).to include('max-age=300')
        expect(cache_control).to include('stale-while-revalidate=30')
      end

      context 'when client has fresh cache' do
        before do
          allow(request).to receive(:fresh?).and_return(true)
        end

        it 'returns false (304 Not Modified)' do
          result = controller.send(:cache_collection, collection)
          expect(result).to be false
        end
      end

      context 'with custom expires_in' do
        it 'sets custom max-age' do
          controller.send(:cache_collection, collection, expires_in: 10.minutes)
          cache_control = response.headers['Cache-Control']
          expect(cache_control).to include('max-age=600')
        end
      end

      context 'with custom stale_while_revalidate' do
        it 'sets custom stale-while-revalidate' do
          controller.send(:cache_collection, collection, stale_while_revalidate: 1.minute)
          cache_control = response.headers['Cache-Control']
          expect(cache_control).to include('stale-while-revalidate=60')
        end
      end
    end

    context 'for authenticated users' do
      let(:user) { create(:user) }

      before { controller.current_user = user }

      it 'returns true without setting cache headers' do
        result = controller.send(:cache_collection, collection)
        expect(result).to be true
      end

      it 'does not set ETag header' do
        controller.send(:cache_collection, collection)
        expect(response.headers['ETag']).to be_nil
      end

      it 'does not set public Cache-Control' do
        controller.send(:cache_collection, collection)
        cache_control = response.headers['Cache-Control']
        expect(cache_control.nil? || !cache_control.include?('public')).to be true
      end
    end
  end

  describe '#cache_resource' do
    let(:store) { @default_store }
    let!(:product) { create(:product, stores: [store]) }

    context 'for guest users' do
      before do
        controller.current_user = nil
        allow(controller).to receive(:stale?).and_return(true)
      end

      it 'returns true when resource is stale' do
        result = controller.send(:cache_resource, product)
        expect(result).to be true
      end

      it 'calls stale? with public: true' do
        expect(controller).to receive(:stale?).with(product, public: true).and_return(true)
        controller.send(:cache_resource, product)
      end

      it 'sets Cache-Control with public and max-age' do
        controller.send(:cache_resource, product)
        cache_control = response.headers['Cache-Control']
        expect(cache_control).to include('public')
        expect(cache_control).to include('max-age=300')
      end

      context 'when resource is fresh (304 Not Modified)' do
        before do
          allow(controller).to receive(:stale?).and_return(false)
        end

        it 'returns false' do
          result = controller.send(:cache_resource, product)
          expect(result).to be false
        end
      end

      context 'with custom expires_in' do
        it 'sets custom max-age' do
          controller.send(:cache_resource, product, expires_in: 15.minutes)
          cache_control = response.headers['Cache-Control']
          expect(cache_control).to include('max-age=900')
        end
      end
    end

    context 'for authenticated users' do
      let(:user) { create(:user) }

      before { controller.current_user = user }

      it 'returns true without calling stale?' do
        expect(controller).not_to receive(:stale?)
        result = controller.send(:cache_resource, product)
        expect(result).to be true
      end
    end
  end

  describe '#collection_cache_key' do
    let(:store) { @default_store }
    let!(:products) { create_list(:product, 3, stores: [store]) }
    let(:collection) { Spree::Product.where(id: products.map(&:id)) }

    it 'includes collection cache_key_with_version' do
      cache_key = controller.send(:collection_cache_key, collection)
      expect(cache_key).to include(collection.cache_key_with_version)
    end

    context 'with include param' do
      let(:params) { { include: 'variants,images' } }

      it 'includes the include param in cache key' do
        cache_key = controller.send(:collection_cache_key, collection)
        expect(cache_key).to include('variants,images')
      end
    end

    context 'with q (ransack) param' do
      let(:params) { { q: { name_cont: 'test' } } }

      it 'includes the q param in cache key' do
        cache_key = controller.send(:collection_cache_key, collection)
        expect(cache_key).to include('name_cont')
      end
    end

    context 'with pagination params' do
      let(:params) { { page: 2, per_page: 10 } }

      it 'includes pagination params in cache key' do
        cache_key = controller.send(:collection_cache_key, collection)
        expect(cache_key).to include('2')
        expect(cache_key).to include('10')
      end
    end

    it 'includes current_currency in cache key' do
      cache_key = controller.send(:collection_cache_key, collection)
      expect(cache_key).to include('USD')
    end

    it 'includes current_locale in cache key' do
      cache_key = controller.send(:collection_cache_key, collection)
      expect(cache_key).to include('en')
    end

    context 'with different currencies' do
      before do
        controller._current_currency = 'EUR'
      end

      it 'generates different cache keys for different currencies' do
        cache_key_eur = controller.send(:collection_cache_key, collection)
        expect(cache_key_eur).to include('EUR')
        expect(cache_key_eur).not_to include('USD')
      end
    end
  end
end
