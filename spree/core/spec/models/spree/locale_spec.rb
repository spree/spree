require 'spec_helper'

RSpec.describe Spree::Locale, type: :model do
  describe '#name' do
    it 'returns the localized display name' do
      expect(described_class.new(code: 'en').name).to eq('English')
    end

    it 'falls back to the code for an unknown locale' do
      expect(described_class.new(code: 'xx').name).to eq('xx')
    end

    it 'strips a trailing parenthetical from a Spree I18n label' do
      I18n.backend.store_translations(:de, spree: { i18n: { this_file_language: 'Deutsch (DE)' } })
      expect(described_class.new(code: 'de').name).to eq('Deutsch')
    end
  end

  describe '#label' do
    it 'formats code and language name' do
      I18n.backend.store_translations(:de, spree: { i18n: { this_file_language: 'Deutsch (DE)' } })
      expect(described_class.new(code: 'de').label).to eq('DE — Deutsch')
    end

    it 'formats the english locale' do
      expect(described_class.new(code: 'en').label).to eq('EN — English')
    end
  end

  # #default? compares the code against the current store's default locale
  # (Spree::Store.current, i.e. Spree::Current.store).
  describe '#default?' do
    let(:store) { build(:store, default_locale: 'en') }

    before { allow(Spree::Current).to receive(:store).and_return(store) }

    it 'is true for the current store default locale' do
      expect(described_class.new(code: 'en')).to be_default
    end

    it 'is false for a non-default locale' do
      expect(described_class.new(code: 'de')).not_to be_default
    end
  end

  describe '#rtl? / #direction' do
    it 'detects right-to-left languages, ignoring region' do
      expect(described_class.new(code: 'ar')).to be_rtl
      expect(described_class.new(code: 'he-IL')).to be_rtl
      expect(described_class.new(code: 'ar').direction).to eq('rtl')
    end

    it 'treats left-to-right languages as ltr' do
      expect(described_class.new(code: 'en')).not_to be_rtl
      expect(described_class.new(code: 'de').direction).to eq('ltr')
    end
  end

  describe 'string-likeness' do
    let(:locale) { described_class.new(code: 'en') }

    it 'stringifies to its code' do
      expect(locale.to_s).to eq('en')
    end

    it 'sorts by code' do
      codes = [described_class.new(code: 'fr'), described_class.new(code: 'de')].sort.map(&:to_s)
      expect(codes).to eq(%w[de fr])
    end

    it 'is equal to another locale with the same code (eql?/hash)' do
      expect(locale).to eql(described_class.new(code: 'en'))
      expect([locale] - [described_class.new(code: 'en')]).to be_empty
    end
  end
end
