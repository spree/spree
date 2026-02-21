require 'spec_helper'

describe Spree::Country, type: :model do
  let(:store) { @default_store }
  let(:america) { store.default_country }
  let(:canada)  { create :country, name: 'Canada', iso_name: 'CANADA', iso: 'CA', iso3: 'CAN', numcode: '124' }

  it 'validates uniqueness' do
    canada.touch
    expect(Spree::Country.new(name: 'Canada', iso: 'CA', iso3: 'CAN', iso_name: 'CANADA')).not_to be_valid
  end

  describe '.by_iso' do
    let(:dummy_iso) { 'XY' }

    it 'will return Country by iso' do
      expect(described_class.by_iso(america.iso)).to eq america
    end

    it 'will return Country by iso3' do
      expect(described_class.by_iso(america.iso3)).to eq america
    end

    it 'will return nil with wrong iso or iso3' do
      expect(described_class.by_iso(dummy_iso)).to eq nil
    end

    it 'will return Country by lower iso' do
      expect(described_class.by_iso(america.iso.downcase)).to eq america
    end
  end

  describe '#default?' do
    before do
      allow_any_instance_of(Spree::Store).to receive(:default).and_return(store)
    end

    context 'no arguments' do
      it 'returns true for store default country' do
        expect(america.default?).to eq(true)
      end

      it 'returns false for other countries' do
        expect(canada.default?).to eq(false)
      end
    end

    context 'other store passed' do
      let(:other_store) { create(:store, default_country: canada) }

      it 'returns true for store default country' do
        expect(canada.default?(other_store)).to eq(true)
      end

      it 'returns false for other countries' do
        expect(america.default?(other_store)).to eq(false)
      end
    end
  end

  describe '#default_currency' do
    it 'returns the currency code from ISO3166' do
      expect(america.default_currency).to eq('USD')
    end

    it 'returns EUR for Germany' do
      germany = create(:country, name: 'Germany', iso_name: 'GERMANY', iso: 'DE', iso3: 'DEU', numcode: '276')
      expect(germany.default_currency).to eq('EUR')
    end

    it 'returns nil for invalid ISO code' do
      invalid_country = build(:country, iso: 'XX')
      expect(invalid_country.default_currency).to be_nil
    end
  end

  describe '#default_locale' do
    it 'returns the primary language from ISO3166' do
      expect(america.default_locale).to eq('en')
    end

    it 'returns de for Germany' do
      germany = create(:country, name: 'Germany', iso_name: 'GERMANY', iso: 'DE', iso3: 'DEU', numcode: '276')
      expect(germany.default_locale).to eq('de')
    end

    it 'returns nil for invalid ISO code' do
      invalid_country = build(:country, iso: 'XX')
      expect(invalid_country.default_locale).to be_nil
    end
  end

  describe '#market_currency' do
    before { Spree::Current.store = store }
    after { Spree::Current.reset }

    context 'when country belongs to a market' do
      let!(:market) { create(:market, :default, store: store, countries: [america], currency: 'EUR') }

      it 'returns the market currency' do
        expect(america.market_currency).to eq('EUR')
      end
    end

    context 'when country does not belong to any market' do
      it 'returns nil' do
        expect(canada.market_currency).to be_nil
      end
    end

    context 'when no current store is set' do
      before { Spree::Current.store = nil }

      it 'returns nil' do
        expect(america.market_currency).to be_nil
      end
    end
  end

  describe '#market_locale' do
    before { Spree::Current.store = store }
    after { Spree::Current.reset }

    context 'when country belongs to a market' do
      let!(:market) { create(:market, :default, store: store, countries: [america], default_locale: 'de') }

      it 'returns the market default locale' do
        expect(america.market_locale).to eq('de')
      end
    end

    context 'when country does not belong to any market' do
      it 'returns nil' do
        expect(canada.market_locale).to be_nil
      end
    end

    context 'when no current store is set' do
      before { Spree::Current.store = nil }

      it 'returns nil' do
        expect(america.market_locale).to be_nil
      end
    end
  end
end
