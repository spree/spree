require 'spec_helper'

describe Spree::LocalizedNames do
  describe '.format_code_name' do
    it 'formats code and name' do
      expect(described_class.format_code_name('en', 'English')).to eq('EN — English')
    end

    it 'returns uppercased code when name matches code' do
      expect(described_class.format_code_name('en', 'en')).to eq('EN')
    end
  end

  describe '.country_name' do
    it 'returns localized country name' do
      expect(described_class.country_name('US', locale: :en)).to include('United States')
    end

    it 'falls back to english then provided fallback' do
      expect(described_class.country_name('US', locale: :zz, fallback: 'Fallback')).to include('United States')
    end

    it 'returns the fallback for an unknown ISO code' do
      expect(described_class.country_name('ZZ', fallback: 'Nowhere')).to eq('Nowhere')
    end
  end

  describe '.country_option_label' do
    let(:country) { build(:country, iso: 'US', name: 'United States') }

    it 'prefixes the localized name with the flag emoji' do
      label = described_class.country_option_label(country, locale: :en)

      expect(label).to include('🇺🇸')
      expect(label).to include('United States')
    end
  end

  describe '.currency_name' do
    it 'returns the currency name for a known code' do
      expect(described_class.currency_name('EUR')).to eq('Euro')
    end

    it 'returns the upcased code for an unknown currency' do
      expect(described_class.currency_name('zzz')).to eq('ZZZ')
    end
  end

  describe '.currency_label' do
    it 'formats currency code and name' do
      expect(described_class.currency_label('EUR')).to eq('EUR — Euro')
    end

    it 'falls back to the bare code for an unknown currency' do
      expect(described_class.currency_label('zzz')).to eq('ZZZ')
    end
  end

  describe '.language_name' do
    it 'returns English for the en locale without a translation bundle' do
      expect(described_class.language_name('en')).to eq('English')
    end

    it 'returns the raw code when no language name is resolvable' do
      expect(described_class.language_name('klingon')).to eq('klingon')
    end
  end

  describe '.normalize_language_name' do
    it 'strips a trailing parenthetical suffix' do
      expect(described_class.normalize_language_name('Deutsch (DE)')).to eq('Deutsch')
    end

    it 'leaves a name without a parenthetical untouched' do
      expect(described_class.normalize_language_name('English')).to eq('English')
    end
  end

  describe '.locale_label' do
    before do
      I18n.backend.store_translations(:de,
        spree: {
          i18n: {
            this_file_language: 'Deutsch (DE)'
          }
        })
    end

    it 'formats locale code and language name' do
      expect(described_class.locale_label(:de)).to eq('DE — Deutsch')
    end

    it 'formats english locale' do
      expect(described_class.locale_label(:en)).to eq('EN — English')
    end
  end
end
