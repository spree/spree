require 'spec_helper'

RSpec.describe Spree::Locale, type: :model do
  describe '#name' do
    it 'returns the localized display name' do
      expect(described_class.new(code: 'en').name).to eq('English')
    end

    it 'falls back to the code for an unknown locale' do
      expect(described_class.new(code: 'xx').name).to eq('xx')
    end
  end

  describe '#default?' do
    let(:store) { build(:store, default_locale: 'en') }

    it 'is true for the store default locale' do
      expect(described_class.new(code: 'en', store: store)).to be_default
    end

    it 'is false for a non-default locale' do
      expect(described_class.new(code: 'de', store: store)).not_to be_default
    end

    it 'is false without a store' do
      expect(described_class.new(code: 'en')).not_to be_default
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
