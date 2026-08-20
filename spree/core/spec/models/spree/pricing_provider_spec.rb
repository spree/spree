require 'spec_helper'

RSpec.describe 'Pricing providers' do
  let(:store) { @default_store }
  let(:variant) { create(:variant, price: 20) }
  let(:context) { Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store) }

  # Answers a fixed amount so a test can tell a provider price from the catalog
  # one, and can be made to fail on demand.
  let(:external_provider_class) do
    Class.new(Spree::PricingProvider::Base) do
      class << self
        attr_accessor :key_name, :fail_with, :handles, :ttl, :calls
      end
      self.key_name = 'contract'
      self.calls = 0

      def self.key = key_name

      def handles?(_context)
        self.class.handles.nil? ? true : self.class.handles
      end

      def cache_ttl = self.class.ttl

      def price_for(context)
        self.class.calls += 1
        raise self.class.fail_with if self.class.fail_with

        Spree::Price.new(variant: context.variant, currency: context.currency, amount: 5)
      end
    end
  end

  before do
    stub_const('SpreeTest::ContractPricingProvider', external_provider_class)
    external_provider_class.fail_with = nil
    external_provider_class.handles = nil
    external_provider_class.ttl = nil
    external_provider_class.calls = 0
  end

  describe 'the default store' do
    it 'prices from the catalog, exactly as before providers existed' do
      expect(store.pricing_provider_instance).to be_a(Spree::PricingProvider::Internal)
      expect(variant.price_for(context).amount).to eq(20)
    end

    it 'returns a persisted, writable price' do
      expect(variant.price_for(context)).to be_persisted
    end
  end

  context 'with an external provider selected' do
    before do
      Spree.pricing_providers << external_provider_class
      stub_store_preferences(store, pricing_provider: 'contract')
    end

    after { Spree.pricing_providers.delete(external_provider_class) }

    it 'answers with the provider price' do
      expect(variant.price_for(context).amount).to eq(5)
    end

    it 'marks the provider price readonly so it cannot leak into the catalog' do
      price = variant.price_for(context)

      expect(price).to be_readonly
      expect { price.save }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    # The contract does not require a provider to set the variant, and the
    # tax-inclusive restatement reads it — without this the price fails deep
    # inside that call with an obscure NoMethodError.
    it 'fills in the variant when a provider builds a price without one' do
      bare = Class.new(Spree::PricingProvider::Base) do
        def self.key = 'bare'
        def price_for(pricing_context) = Spree::Price.new(currency: pricing_context.currency, amount: 7)
      end
      Spree.pricing_providers << bare
      stub_store_preferences(store, pricing_provider: 'bare')

      expect(variant.price_for(context).variant).to eq(variant)
    ensure
      Spree.pricing_providers.delete(bare)
    end

    it 'falls back to the catalog for a context the provider declines' do
      external_provider_class.handles = false

      expect(variant.price_for(context).amount).to eq(20)
      expect(external_provider_class.calls).to eq(0)
    end

    it 'caches by context when the provider asks for it' do
      external_provider_class.ttl = 5.minutes

      with_memory_cache do
        expect(variant.price_for(context).amount).to eq(5)
        expect(variant.price_for(context).amount).to eq(5)
      end

      expect(external_provider_class.calls).to eq(1)
    end

    # Contexts carry the moment they were built; two shoppers a second apart
    # must still share the entry or the cache never hits at all.
    it 'shares the cached answer across requests made at different moments' do
      external_provider_class.ttl = 5.minutes
      later = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store, date: 1.second.from_now)

      with_memory_cache do
        variant.price_for(context)
        variant.price_for(later)
      end

      expect(external_provider_class.calls).to eq(1)
    end

    it 'does not serve one shopper the price cached for another' do
      external_provider_class.ttl = 5.minutes
      other = Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store,
                                          user: create(:user), quantity: 10)

      with_memory_cache do
        variant.price_for(context)
        variant.price_for(other)
      end

      expect(external_provider_class.calls).to eq(2)
    end

    describe 'when the provider is unreachable' do
      before { external_provider_class.fail_with = Timeout::Error }

      it 'refuses to price a cart under the default strict policy' do
        cart = create(:cart, store: store)
        checkout_context = Spree::Pricing::Context.from_order(variant, cart, quantity: 1)

        expect { variant.price_for(checkout_context) }.
          to raise_error(Spree::Pricing::PriceResolution::ProviderUnavailable)
      end

      # Strict is about not charging an unconfirmed price. The catalog must
      # keep rendering; a listing that 500s while the ERP hiccups is worse
      # than a tile with no price on it.
      it 'answers no price, rather than raising, on a catalog read' do
        expect(variant.price_for(context)).to be_nil
      end

      it 'uses the catalog price when the store opts into falling back' do
        stub_store_preferences(store, pricing_provider: 'contract', pricing_provider_failure_policy: 'fallback')

        expect(variant.price_for(context).amount).to eq(20)
      end

      it 'reports the fallback so an operator can see it happening' do
        stub_store_preferences(store, pricing_provider: 'contract', pricing_provider_failure_policy: 'fallback')
        events = []
        callback = ->(*, payload) { events << payload }

        ActiveSupport::Notifications.subscribed(callback, 'provider.fallback.spree') do
          variant.price_for(context)
        end

        expect(events.first).to include(provider: 'contract', kind: 'pricing', reason: 'Timeout::Error')
      end
    end
  end

  describe 'an unknown provider key' do
    it 'falls back to the catalog rather than taking the store down' do
      stub_store_preferences(store, pricing_provider: 'uninstalled_gem')

      expect(store.pricing_provider_instance).to be_a(Spree::PricingProvider::Internal)
      expect(variant.price_for(context).amount).to eq(20)
    end
  end

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end
end
