require 'spec_helper'

RSpec.describe Spree::StoreScopeGuard do
  after { Spree::Config.store_scope_guard = nil }

  describe 'raise mode' do
    before { Spree::Config.store_scope_guard = 'raise' }

    it 'raises for a store-less query on a store-owned table inside the window' do
      expect {
        described_class.watch { Spree::Product.where(name: 'x').to_a }
      }.to raise_error(described_class::UnscopedQueryError, /spree_products/)
    end

    it 'passes a query carrying a store_id predicate' do
      expect {
        described_class.watch { Spree::Product.where(store_id: 1).to_a }
      }.not_to raise_error
    end

    it 'passes id and foreign-key filters (ids in hand came from scoped rows)' do
      expect {
        described_class.watch { Spree::Order.where(customer_id: 1).to_a }
      }.not_to raise_error
    end

    it 'ignores tables without a store_id column' do
      expect {
        described_class.watch { Spree::Country.where(iso: 'US').to_a }
      }.not_to raise_error
    end

    it 'ignores the stores table itself' do
      expect {
        described_class.watch { Spree::Store.where(default: true).to_a }
      }.not_to raise_error
    end

    it 'is inert outside a watched window' do
      described_class.watch { Spree::Store.default } # installs the subscriber

      expect { Spree::Product.where(name: 'x').to_a }.not_to raise_error
    end

    it 'lets a deliberately global lookup opt out with skip' do
      expect {
        described_class.watch do
          described_class.skip { Spree::Product.where(name: 'x').to_a }
        end
      }.not_to raise_error
    end
  end

  describe 'log mode' do
    before { Spree::Config.store_scope_guard = 'log' }

    it 'warns instead of raising' do
      expect(Rails.logger).to receive(:warn).with(/spree_products/)

      described_class.watch { Spree::Product.where(name: 'x').to_a }
    end
  end

  describe 'off mode' do
    before { Spree::Config.store_scope_guard = 'off' }

    it 'does not watch at all' do
      expect(Rails.logger).not_to receive(:warn)

      described_class.watch { Spree::Product.where(name: 'x').to_a }
    end
  end
end
