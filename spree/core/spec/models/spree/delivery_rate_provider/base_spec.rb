require 'spec_helper'

RSpec.describe Spree::DeliveryRateProvider::Base do
  let(:store) { @default_store }
  let(:delivery_method) { create(:delivery_method, store: store) }

  describe 'the contract' do
    it 'requires subclasses to implement estimate' do
      expect { described_class.new(delivery_method).estimate(nil) }.to raise_error(NotImplementedError)
    end

    it 'no-ops the optional lifecycle hooks' do
      provider = described_class.new(delivery_method)

      expect { provider.book(nil) }.not_to raise_error
      expect { provider.release(nil) }.not_to raise_error
    end

    it 'needs no integration by default' do
      expect(described_class.integration_class).to be_nil
      expect(described_class.available_for_store?(store)).to be(true)
    end
  end

  describe 'credential resolution' do
    let(:provider_class) do
      Class.new(described_class) do
        def self.integration_class = 'Spree::Integration'

        # Exposed so the spec can assert on the resolved record.
        def resolved_integration = integration
      end
    end

    before { stub_const('TestRateProvider', provider_class) }

    it 'resolves the active integration from the method store' do
      integration = create(:integration, store: store, active: true)

      expect(TestRateProvider.new(delivery_method).resolved_integration).to eq(integration)
    end

    it 'ignores inactive integrations' do
      create(:integration, store: store, active: false)

      expect(TestRateProvider.new(delivery_method).resolved_integration).to be_nil
    end

    # Declaring integration_class is all a carrier provider needs —
    # availability is derived from it, so forgetting a hand-written override
    # can't silently offer an unconnected provider.
    describe '.available_for_store?' do
      it 'follows the connected integration' do
        expect(TestRateProvider.available_for_store?(store)).to be(false)

        create(:integration, store: store, active: true)

        expect(TestRateProvider.available_for_store?(store)).to be(true)
      end

      it 'ignores inactive integrations' do
        create(:integration, store: store, active: false)

        expect(TestRateProvider.available_for_store?(store)).to be(false)
      end
    end
  end

  describe 'registry' do
    it 'registers the Internal provider' do
      expect(Spree.delivery_rate_providers).to include(Spree::DeliveryRateProvider::Internal)
    end
  end
end
