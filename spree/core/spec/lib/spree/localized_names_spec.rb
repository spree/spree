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
  end

  describe '.currency_label' do
    it 'formats currency code and name' do
      expect(described_class.currency_label('EUR')).to eq('EUR — Euro')
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
