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

  describe '#tax_country' do
    context 'when tax_country is set' do
      let(:country) { create(:country) }

      before { described_class.tax_country = country }

      it 'returns the set country' do
        expect(described_class.tax_country).to eq(country)
      end
    end

    context 'when tax_country is not set' do
      let!(:store) { create(:store, default: true) }
      let(:market) { create(:market, store: store) }

      it 'falls back to the market being browsed' do
        described_class.market = market

        expect(described_class.tax_country).to eq(market.default_country)
      end

      it 'falls back to the store country when the market has none' do
        allow(market).to receive(:default_country).and_return(nil)
        described_class.market = market

        expect(described_class.tax_country).to eq(store.default_country)
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

    context 'when the store has no default locale' do
      let!(:store) { create(:store, default: true, default_locale: nil) }

      it 'falls back to the I18n default locale' do
        expect(described_class.locale).to eq(I18n.default_locale.to_s)
      end
    end
  end

  describe '#content_locale' do
    context 'when content_locale is set' do
      before { described_class.content_locale = 'de' }

      it 'returns the set content locale' do
        expect(described_class.content_locale).to eq('de')
      end
    end

    context 'when content_locale is not set' do
      it 'falls back to the application default locale' do
        expect(described_class.content_locale).to eq(I18n.default_locale.to_s)
      end

      it 'does not fall back to the store default locale' do
        # Outside a request nothing assigns the content locale; deriving it
        # from the store would silently change how jobs and rake tasks read
        # translated attributes.
        create(:store, default: true, default_locale: 'de')
        expect(described_class.content_locale).to eq(I18n.default_locale.to_s)
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

    context 'when market is not set' do
      let!(:store) { create(:store, default: true) }

      it 'falls back to the store default market' do
        expect(described_class.market).to eq(store.default_market)
      end
    end
  end

  describe '#global_pricing_context' do
    let!(:store) { create(:store, default: true, default_currency: 'USD') }
    let(:market) { create(:market, store: store) }

    before do
      described_class.store = store
      described_class.currency = 'USD'
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

    it 'uses the country whose tax applies' do
      described_class.tax_country = create(:country, iso: 'PT', name: 'Portugal')

      expect(described_class.global_pricing_context.country.iso).to eq('PT')
    end

    it 'falls back to the market country when none was set' do
      expect(described_class.global_pricing_context.country).to eq(market.default_country)
      expect(described_class.global_pricing_context.country).to be_present
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

    it 'excludes catalog-owned price lists — pricing reaches them through the catalog walk' do
      owned = create(:price_list, :active, store: store, catalog: create(:catalog, store: store))

      expect(described_class.price_lists).not_to include(owned)
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

  describe '#catalogs_for' do
    let(:store) { @default_store }
    let!(:company) { create(:company, store: store) }
    let!(:assigned_catalog) { create(:catalog, store: store) }
    let!(:other_catalog) { create(:catalog, store: store) }

    before do
      create(:catalog_assignment, catalog: assigned_catalog, assignable: company)
      described_class.store = store
    end

    it 'returns only catalogs that apply to the buyer, not every catalog in the store' do
      expect(described_class.catalogs_for(company: company)).to eq([assigned_catalog])
      expect(described_class.catalogs_for(company: company)).not_to include(other_catalog)
    end

    it 'memoizes the applicable set for the same buyer' do
      first = described_class.catalogs_for(company: company)
      second = described_class.catalogs_for(company: company)
      expect(first).to be(second)
    end

    it 'does not reuse one buyer set for another' do
      other_company = create(:company, store: store)
      other_assigned = create(:catalog, store: store)
      create(:catalog_assignment, catalog: other_assigned, assignable: other_company)

      expect(described_class.catalogs_for(company: company)).to eq([assigned_catalog])
      expect(described_class.catalogs_for(company: other_company)).to eq([other_assigned])
    end

    it 'drops the memoized set when a catalog is written' do
      expect(described_class.catalogs_for(company: company)).to eq([assigned_catalog])

      created = create(:catalog, store: store)
      create(:catalog_assignment, catalog: created, assignable: company)

      expect(described_class.catalogs_for(company: company)).to contain_exactly(assigned_catalog, created)
    end
  end

  describe '.reset' do
    let(:store) { create(:store) }
    let(:country) { create(:country) }

    before do
      described_class.store = store
      described_class.currency = 'EUR'
      described_class.tax_country = country
    end

    it 'resets all attributes' do
      described_class.reset

      # After reset, store returns default, not the set store
      expect(described_class.store).not_to eq(store)
      expect(described_class.store).to eq(Spree::Store.default)

      # Currency falls back to store default
      expect(described_class.currency).not_to eq('EUR')

      # Tax country falls back to the store's own
      expect(described_class.tax_country).not_to eq(country)
    end

    it 'clears memoized price_lists' do
      # Access price_lists to memoize
      described_class.price_lists

      described_class.reset

      # After reset, price_lists should be fetched fresh
      expect(described_class.instance_variable_get(:@price_lists)).to be_nil
    end

    it 'clears memoized applicable catalogs' do
      described_class.catalogs_for

      described_class.reset

      expect(described_class.instance_variable_get(:@applicable_catalogs)).to be_nil
    end

    it 'clears memoized global_pricing_context' do
      # Access global_pricing_context to memoize
      described_class.global_pricing_context

      described_class.reset

      # After reset, global_pricing_context should be fetched fresh
      expect(described_class.instance_variable_get(:@global_pricing_context)).to be_nil
    end
  end

  describe '#provider_cache' do
    it 'defaults to a hash providers can memoize into' do
      described_class.provider_cache[:quote] = 'cached'

      expect(described_class.provider_cache[:quote]).to eq('cached')
    end

    # Carrier quotes are request-scoped; leaking them across requests would
    # price one customer's checkout with another's destination.
    it 'is cleared between requests' do
      described_class.provider_cache[:quote] = 'cached'

      described_class.reset

      expect(described_class.provider_cache).to eq({})
    end
  end

  describe '#integrations' do
    it 'loads the current store\'s active integrations once and serves the snapshot' do
      active = create(:integration, store: @default_store, active: true)

      expect(described_class.integrations).to eq([active])
      expect(described_class.integrations.object_id).to eq(described_class.integrations.object_id)
    end

    # The activate-and-verify flow writes an integration mid-request; later
    # reads must see it rather than the snapshot taken before.
    it 'drops the snapshot when an integration is written' do
      expect(described_class.integrations).to eq([])

      connected = create(:integration, store: @default_store, active: true)

      expect(described_class.integrations).to eq([connected])
    end
  end
end
