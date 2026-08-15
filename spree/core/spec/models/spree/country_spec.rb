require 'spec_helper'

describe Spree::Country, type: :model do
  let(:store) { @default_store }
  let(:america) { store.default_country }
  let(:canada)  { described_class.by_iso('CA') }

  describe '.all' do
    it 'lists the countries a store can sell to' do
      expect(described_class.all.map(&:iso)).to include('US', 'DE', 'PL')
    end

    it 'omits territories that can never be ordered to' do
      expect(described_class.all.map(&:iso)).not_to include('AQ')
    end
  end

  describe '#states' do
    it 'lists the country subdivisions' do
      expect(america.states.map(&:abbr)).to include('CA', 'NY')
    end

    it 'is empty for a country with no subdivisions' do
      expect(described_class.by_iso('HK').states).to be_empty
    end
  end

  describe 'equality' do
    it 'is equal to the same country' do
      expect(described_class.by_iso('US')).to eq(described_class.by_iso('US'))
    end

    it 'deduplicates by ISO' do
      expect([described_class.by_iso('US'), described_class.by_iso('US')].uniq.size).to eq(1)
    end
  end

  describe '#localized_name' do
    it 'returns the localized country name' do
      expect(described_class.new(iso: 'US').localized_name(locale: :en)).to include('United States')
    end

    it 'falls back to the iso for an unknown code' do
      expect(described_class.new(iso: 'ZZ').localized_name).to eq('ZZ')
    end
  end

  describe '#option_label' do
    it 'prefixes the localized name with the flag emoji' do
      label = described_class.new(iso: 'US').option_label(locale: :en)
      expect(label).to include('🇺🇸')
      expect(label).to include('United States')
    end
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

  describe '#current_market' do
    let!(:market) { store.default_market }

    before do
      allow(Spree::Current).to receive(:store).and_return(store)
      america.instance_variable_set(:@current_market, nil)
      canada.instance_variable_set(:@current_market, nil)
    end

    it 'returns the market for the country in the current store' do
      expect(america.current_market).to eq(market)
    end

    it 'returns nil for a country not in any market' do
      expect(canada.current_market).to be_nil
    end

    it 'returns nil when there is no current store' do
      allow(Spree::Current).to receive(:store).and_return(nil)
      expect(america.current_market).to be_nil
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
end
