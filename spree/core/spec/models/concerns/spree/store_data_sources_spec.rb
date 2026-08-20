require 'spec_helper'

RSpec.describe Spree::StoreDataSources do
  let(:store) { create(:store) }

  describe 'defaults' do
    it 'uses Spree own catalog and stock records' do
      expect(store.pricing_provider_instance).to be_a(Spree::PricingProvider::Internal)
      expect(store.inventory_provider_instance).to be_a(Spree::InventoryProvider::Internal)
      expect(store).to be_internal_pricing
      expect(store).to be_internal_inventory
    end

    # The asymmetry is the point: selling stock that turns out not to exist is
    # recoverable, charging the wrong price is a dispute.
    it 'refuses to price without its provider but will sell on a stale stock figure' do
      expect(store.pricing_failure_policy).to eq('strict')
      expect(store.inventory_failure_policy).to eq('fallback')
    end
  end

  describe 'validation' do
    it 'rejects a failure policy that is neither falling back nor strict' do
      store.preferred_pricing_provider_failure_policy = 'ignore'

      expect(store).not_to be_valid
      expect(store.errors[:preferred_pricing_provider_failure_policy]).to be_present
    end

    it 'accepts both known policies' do
      Spree::ProviderFailurePolicy::VALUES.each do |policy|
        store.preferred_inventory_provider_failure_policy = policy

        expect(store).to be_valid
      end
    end
  end

  describe 'selection' do
    let(:provider_class) do
      Class.new(Spree::PricingProvider::Base) do
        def self.key = 'contract'
        def price_for(_context) = nil
      end
    end

    before { Spree.pricing_providers << provider_class }
    after { Spree.pricing_providers.delete(provider_class) }

    it 'resolves a registered provider by its key' do
      stub_store_preferences(store, pricing_provider: 'contract')

      expect(store.pricing_provider_instance).to be_a(provider_class)
      expect(store).not_to be_internal_pricing
    end

    # A store object outlives the setting: a merchant switching provider, or a
    # job holding one for hours, must not keep getting the old answer.
    it 'follows a preference change rather than answering from a stale instance' do
      store.update!(preferred_pricing_provider: 'contract')
      expect(store.pricing_provider_instance).to be_a(provider_class)

      store.update!(preferred_pricing_provider: 'internal')

      expect(store.pricing_provider_instance).to be_a(Spree::PricingProvider::Internal)
    end

    # A gem removed from the Gemfile must not take pricing down with it.
    it 'falls back to internal when the key names a provider that is gone' do
      stub_store_preferences(store, pricing_provider: 'removed_gem')

      expect(store.pricing_provider_instance).to be_a(Spree::PricingProvider::Internal)
    end
  end

  describe 'availability for a store' do
    let(:integration_provider) do
      Class.new(Spree::PricingProvider::Base) do
        def self.key = 'needs_credentials'
        def self.integration_class = 'SpreeTest::Integration'
      end
    end

    it 'is unavailable until its integration is connected' do
      expect(integration_provider.available_for_store?(store)).to be(false)
    end

    it 'needs no integration when it declares none' do
      expect(Spree::PricingProvider::Internal.available_for_store?(store)).to be(true)
    end
  end

  describe 'registry keys' do
    it 'names the internal providers by the key the preference stores' do
      expect(Spree::PricingProvider::Internal.key).to eq('internal')
      expect(Spree::InventoryProvider::Internal.key).to eq('internal')
    end
  end
end
