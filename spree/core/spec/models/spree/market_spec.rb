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
      create(:market, :default, store: store)
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

  describe '#supported_locales=' do
    let(:market) { build(:market, store: store, default_locale: 'en') }

    it 'joins an array into a comma-separated string' do
      market.supported_locales = %w[fr de]
      expect(market.read_attribute(:supported_locales)).to eq('fr,de')
    end

    it 'accepts a plain string verbatim' do
      market.supported_locales = 'fr,de'
      expect(market.read_attribute(:supported_locales)).to eq('fr,de')
    end

    it 'strips blanks and deduplicates array entries' do
      market.supported_locales = ['fr', '', 'de', 'fr', nil]
      expect(market.read_attribute(:supported_locales)).to eq('fr,de')
    end

    it 'clears the memoized supported_locales_list on assignment' do
      market.supported_locales = %w[fr]
      expect(market.supported_locales_list).to eq(%w[en fr])

      market.supported_locales = %w[de]
      expect(market.supported_locales_list).to eq(%w[de en])
    end

    it 'persists the comma-string after save' do
      market.supported_locales = %w[fr de]
      market.save!
      expect(market.reload.read_attribute(:supported_locales)).to eq('fr,de')
    end
  end

  describe '#country_isos' do
    it 'returns the sorted ISO codes for assigned countries' do
      de = create(:country, iso: 'DE', name: 'Germany')
      fr = create(:country, iso: 'FR', name: 'France')
      market = create(:market, store: store, countries: [fr, de])

      expect(market.country_isos).to eq(%w[DE FR])
    end

    it 'returns an empty array when no countries are assigned' do
      market = build(:market, store: store, countries: [])
      expect(market.country_isos).to eq([])
    end

    it 'reflects updates made via country_isos=' do
      create(:country, iso: 'DE', name: 'Germany')
      create(:country, iso: 'FR', name: 'France')
      market = build(:market, store: store, countries: [])
      market.country_isos = %w[FR DE]
      expect(market.country_isos).to eq(%w[DE FR])
    end

    it 'round-trips through save/reload' do
      de = create(:country, iso: 'DE', name: 'Germany')
      fr = create(:country, iso: 'FR', name: 'France')
      market = create(:market, store: store, countries: [de, fr])
      expect(market.reload.country_isos).to eq(%w[DE FR])
    end
  end

  describe '#country_isos=' do
    let!(:de) { create(:country, iso: 'DE', name: 'Germany') }
    let!(:fr) { create(:country, iso: 'FR', name: 'France') }
    let!(:italy) { create(:country, iso: 'IT', name: 'Italy') }

    it 'resolves ISO codes to Country records' do
      market = build(:market, store: store, countries: [])
      market.country_isos = %w[DE FR]
      expect(market.countries).to contain_exactly(de, fr)
    end

    it 'is case-insensitive' do
      market = build(:market, store: store, countries: [])
      market.country_isos = %w[de fr]
      expect(market.countries).to contain_exactly(de, fr)
    end

    it 'silently drops unknown codes' do
      market = build(:market, store: store, countries: [])
      market.country_isos = %w[DE XX FR]
      expect(market.countries).to contain_exactly(de, fr)
    end

    it 'replaces the existing country list (full-set update)' do
      market = build(:market, store: store, countries: [de, fr])
      market.country_isos = %w[IT]
      expect(market.countries).to contain_exactly(italy)
    end

    it 'clears all countries when given an empty array' do
      market = build(:market, store: store, countries: [de])
      market.country_isos = []
      expect(market.countries).to be_empty
    end

    it 'strips blanks and nils' do
      market = build(:market, store: store, countries: [])
      market.country_isos = ['DE', '', nil, 'FR']
      expect(market.countries).to contain_exactly(de, fr)
    end
  end

  describe '#can_be_deleted?' do
    it 'returns false for the default market' do
      create(:market, store: store)
      market = create(:market, :default, store: store)
      expect(market.can_be_deleted?).to be false
    end

    it 'returns false for the only market in a store' do
      market = create(:market, store: store)
      expect(market.can_be_deleted?).to be false
    end

    it 'returns true for a non-default market when other markets remain' do
      create(:market, :default, store: store)
      market = create(:market, store: store)
      expect(market.can_be_deleted?).to be true
    end
  end

  describe 'destroy' do
    it 'does not allow destroying the default market' do
      create(:market, store: store)
      market = create(:market, :default, store: store)
      expect(market.destroy).to be false
      expect(market.reload.deleted_at).to be_nil
      expect(market.errors[:base]).to include(I18n.t('activerecord.errors.models.spree/market.attributes.base.cannot_destroy_default_market'))
    end

    it 'does not allow destroying the only market in a store' do
      market = create(:market, store: store)
      expect(market.destroy).to be false
      expect(market.reload.deleted_at).to be_nil
      expect(market.errors[:base]).to include(I18n.t('activerecord.errors.models.spree/market.attributes.base.cannot_destroy_last_market'))
    end

    it 'allows destroying a non-default market when other markets remain' do
      create(:market, :default, store: store)
      market = create(:market, store: store)
      expect { market.destroy }.to change { market.reload.deleted_at }.from(nil).to(be_present)
    end

    it 'does not affect markets in other stores when checking for last market' do
      other_store = create(:store)
      create(:market, store: other_store)
      market = create(:market, store: store)
      expect(market.destroy).to be false
      expect(market.errors[:base]).to include(I18n.t('activerecord.errors.models.spree/market.attributes.base.cannot_destroy_last_market'))
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
