require 'spec_helper'

RSpec.describe Spree::Current do
  after do
    described_class.reset
  end

  describe '#store' do
    context 'when store is set' do
      let(:store) { create(:store) }

      before { described_class.store = store }

      it 'returns the set store' do
        expect(described_class.store).to eq(store)
      end
    end

    context 'when store is not set' do
      it 'returns the default store' do
        expect(described_class.store).to eq(Spree::Store.default)
      end
    end
  end

  describe '#currency' do
    context 'when currency is set' do
      before { described_class.currency = 'EUR' }

      it 'returns the set currency' do
        expect(described_class.currency).to eq('EUR')
      end
    end

    context 'when currency is not set' do
      let!(:store) { create(:store, default: true, default_currency: 'GBP') }

      it 'returns the default currency from the store' do
        expect(described_class.currency).to eq('GBP')
      end
    end
  end

  describe '#zone' do
    context 'when zone is set' do
      let(:zone) { create(:zone) }

      before { described_class.zone = zone }

      it 'returns the set zone' do
        expect(described_class.zone).to eq(zone)
      end
    end

    context 'when zone is not set' do
      let!(:default_zone) { create(:zone, default_tax: true) }

      it 'returns the default tax zone' do
        expect(described_class.zone).to eq(default_zone)
      end
    end

    context 'when zone is not set and no default tax zone exists' do
      before do
        Spree::Zone.update_all(default_tax: false)
      end

      context 'when store has a checkout_zone' do
        let(:checkout_zone) { create(:zone) }
        let!(:store) { create(:store, default: true, checkout_zone: checkout_zone) }

        it 'returns the store checkout_zone' do
          expect(described_class.zone).to eq(checkout_zone)
        end
      end

      context 'when store has no checkout_zone' do
        it 'returns nil' do
          expect(described_class.zone).to be_nil
        end
      end
    end
  end

  describe '.reset' do
    let(:store) { create(:store) }
    let(:zone) { create(:zone) }

    before do
      described_class.store = store
      described_class.currency = 'EUR'
      described_class.zone = zone
    end

    it 'resets all attributes' do
      described_class.reset

      # After reset, store returns default, not the set store
      expect(described_class.store).not_to eq(store)
      expect(described_class.store).to eq(Spree::Store.default)

      # Currency falls back to store default
      expect(described_class.currency).not_to eq('EUR')

      # Zone falls back to default tax zone
      expect(described_class.zone).not_to eq(zone)
    end
  end
end
