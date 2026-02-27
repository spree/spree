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

      it 'returns nil' do
        expect(described_class.zone).to be_nil
      end
    end
  end

  describe '#default_tax_zone' do
    context 'when default_tax_zone is explicitly set' do
      let(:zone) { create(:zone) }

      before { described_class.default_tax_zone = zone }

      it 'returns the set zone' do
        expect(described_class.default_tax_zone).to eq(zone)
      end
    end

    context 'when default_tax_zone is not set' do
      let!(:default_zone) { create(:zone, default_tax: true) }

      it 'returns the default tax zone from the database' do
        expect(described_class.default_tax_zone).to eq(default_zone)
      end

      it 'memoizes the result' do
        described_class.default_tax_zone

        expect(Spree::Zone).not_to receive(:find_by)
        described_class.default_tax_zone
      end
    end

    context 'when no default tax zone exists' do
      before { Spree::Zone.update_all(default_tax: false) }

      it 'returns nil' do
        expect(described_class.default_tax_zone).to be_nil
      end

      it 'does not re-query on subsequent calls' do
        described_class.default_tax_zone

        expect(Spree::Zone).not_to receive(:find_by)
        described_class.default_tax_zone
      end
    end
  end

  describe '#locale' do
    context 'when locale is set' do
      before { described_class.locale = 'fr' }

      it 'returns the set locale' do
        expect(described_class.locale).to eq('fr')
      end
    end

    context 'when locale is not set but market has a default locale' do
      let!(:store) { create(:store, default: true, default_locale: 'en') }
      let!(:market) { create(:market, store: store, default: true, default_locale: 'de') }

      it 'returns the market default locale' do
        expect(described_class.locale).to eq('de')
      end
    end

    context 'when locale is not set and no market exists' do
      let!(:store) { create(:store, default: true, default_locale: 'en') }

      it 'returns the store default locale' do
        expect(described_class.locale).to eq('en')
      end
    end
  end

  describe '#market' do
    context 'when market is set' do
      let(:market) { create(:market) }

      before { described_class.market = market }

      it 'returns the set market' do
        expect(described_class.market).to eq(market)
      end
    end

    context 'when market is not set' do
      let!(:store) { create(:store, default: true) }
      let!(:market) { create(:market, store: store, default: true) }

      it 'returns the default market from the store' do
        expect(described_class.market).to eq(market)
      end
    end

    context 'when market is not set and store has no markets' do
      let!(:store) { create(:store, default: true) }

      it 'returns nil' do
        expect(described_class.market).to be_nil
      end
    end
  end

  describe '#global_pricing_context' do
    let!(:store) { create(:store, default: true, default_currency: 'USD') }
    let(:zone) { create(:zone, default_tax: true) }
    let(:market) { create(:market, store: store) }

    before do
      described_class.store = store
      described_class.currency = 'USD'
      described_class.zone = zone
      described_class.market = market
    end

    it 'returns a Spree::Pricing::Context' do
      expect(described_class.global_pricing_context).to be_a(Spree::Pricing::Context)
    end

    it 'uses the current store' do
      expect(described_class.global_pricing_context.store).to eq(store)
    end

    it 'uses the current currency' do
      expect(described_class.global_pricing_context.currency).to eq('USD')
    end

    it 'uses the current zone' do
      expect(described_class.global_pricing_context.zone).to eq(zone)
    end

    it 'uses the current market' do
      expect(described_class.global_pricing_context.market).to eq(market)
    end

    it 'memoizes the context' do
      context1 = described_class.global_pricing_context
      context2 = described_class.global_pricing_context
      expect(context1).to be(context2)
    end
  end

  describe '#price_lists' do
    let!(:store) { create(:store, default: true) }
    let!(:other_store) { create(:store) }
    let!(:active_price_list) { create(:price_list, :active, store: store, position: 1) }
    let!(:scheduled_price_list) { create(:price_list, :scheduled, store: store, position: 2, starts_at: 1.day.ago, ends_at: 1.day.from_now) }
    let!(:inactive_price_list) { create(:price_list, :inactive, store: store) }
    let!(:other_store_price_list) { create(:price_list, :active, store: other_store) }

    before do
      described_class.store = store
    end

    it 'returns price lists for the current store' do
      expect(described_class.price_lists).to include(active_price_list)
      expect(described_class.price_lists).not_to include(other_store_price_list)
    end

    it 'includes active price lists' do
      expect(described_class.price_lists).to include(active_price_list)
    end

    it 'includes scheduled price lists within date range' do
      expect(described_class.price_lists).to include(scheduled_price_list)
    end

    it 'excludes inactive price lists' do
      expect(described_class.price_lists).not_to include(inactive_price_list)
    end

    it 'returns price lists ordered by position' do
      expect(described_class.price_lists.to_a).to eq([active_price_list, scheduled_price_list])
    end

    it 'memoizes the price lists' do
      lists1 = described_class.price_lists
      lists2 = described_class.price_lists
      expect(lists1).to be(lists2)
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

    it 'clears memoized price_lists' do
      # Access price_lists to memoize
      described_class.price_lists

      described_class.reset

      # After reset, price_lists should be fetched fresh
      expect(described_class.instance_variable_get(:@price_lists)).to be_nil
    end

    it 'clears memoized global_pricing_context' do
      # Access global_pricing_context to memoize
      described_class.global_pricing_context

      described_class.reset

      # After reset, global_pricing_context should be fetched fresh
      expect(described_class.instance_variable_get(:@global_pricing_context)).to be_nil
    end

    it 'clears memoized default_tax_zone' do
      create(:zone, default_tax: true)
      described_class.default_tax_zone

      described_class.reset

      expect(described_class.instance.instance_variable_get(:@default_tax_zone_loaded)).to be false
    end
  end
end
