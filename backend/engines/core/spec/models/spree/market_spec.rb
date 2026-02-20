require 'spec_helper'

RSpec.describe Spree::Market, type: :model do
  let(:store) { create(:store) }

  describe 'validations' do
    subject { build(:market, store: store) }

    it { is_expected.to validate_presence_of(:store) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:default_locale) }

    it 'validates presence of countries' do
      market = build(:market, store: store, countries: [])
      expect(market).not_to be_valid
      expect(market.errors[:countries]).to be_present
    end

    it 'validates uniqueness of name scoped to store' do
      create(:market, name: 'North America', store: store)
      market = build(:market, name: 'North America', store: store)
      expect(market).not_to be_valid
      expect(market.errors[:name]).to be_present
    end
  end

  describe 'associations' do
    it 'has many countries through market_countries' do
      country1 = create(:country)
      country2 = create(:country)
      market = create(:market, store: store, countries: [country1, country2])

      expect(market.countries).to contain_exactly(country1, country2)
    end

    it 'destroys market_countries on destroy' do
      market = create(:market, store: store)
      expect { market.destroy }.to change(Spree::MarketCountry, :count).by(-1)
    end
  end

  describe '.for_country' do
    let(:country) { create(:country) }

    it 'finds market by country' do
      market = create(:market, store: store, countries: [country])
      result = described_class.for_country(country, store: store)
      expect(result).to eq(market)
    end

    it 'returns nil when no market matches' do
      other_country = create(:country)
      create(:market, store: store, countries: [country])
      result = described_class.for_country(other_country, store: store)
      expect(result).to be_nil
    end

    it 'returns nil when country is nil' do
      expect(described_class.for_country(nil, store: store)).to be_nil
    end
  end

  describe '.default_for_store' do
    it 'returns default market' do
      create(:market, store: store)
      default = create(:market, :default, store: store)
      expect(described_class.default_for_store(store)).to eq(default)
    end

    it 'falls back to first by position' do
      market = create(:market, store: store, position: 1)
      create(:market, store: store, position: 2)
      expect(described_class.default_for_store(store)).to eq(market)
    end

    it 'returns nil for store without markets' do
      expect(described_class.default_for_store(store)).to be_nil
    end
  end

  describe '#supported_locales_list' do
    it 'returns default_locale when supported_locales is blank' do
      market = build(:market, default_locale: 'en', supported_locales: nil)
      expect(market.supported_locales_list).to eq(['en'])
    end

    it 'includes both supported_locales and default_locale' do
      market = build(:market, default_locale: 'en', supported_locales: 'fr,de')
      expect(market.supported_locales_list).to eq(['de', 'en', 'fr'])
    end

    it 'deduplicates locales' do
      market = build(:market, default_locale: 'en', supported_locales: 'en,fr')
      expect(market.supported_locales_list).to eq(['en', 'fr'])
    end
  end

  describe '#ensure_single_default' do
    it 'clears other default markets when setting default' do
      first = create(:market, :default, store: store)
      second = create(:market, :default, store: store)
      expect(first.reload.default).to be false
      expect(second.reload.default).to be true
    end

    it 'does not affect markets in other stores' do
      other_store = create(:store)
      other_default = create(:market, :default, store: other_store)
      create(:market, :default, store: store)
      expect(other_default.reload.default).to be true
    end
  end

  describe 'has_prefix_id' do
    it 'generates prefixed id with mkt prefix' do
      market = create(:market, store: store)
      expect(market.prefixed_id).to start_with('mkt_')
    end
  end
end
