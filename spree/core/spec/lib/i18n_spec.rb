require 'spec_helper'

describe 'i18n' do
  before do
    I18n.backend.store_translations(:en, spree: { foo: 'bar', bar: { foo: 'bar within bar scope' } })
  end

  describe '#available_locales' do
    it 'returns the locales Spree ships translations for, including English' do
      expect(Spree.available_locales).to include(:en, :de, :'pt-BR')
    end

    it 'leaves out shipped locales the app does not allow' do
      allow(Rails.application.config.i18n).to receive(:available_locales).and_return(%i[en de])

      expect(Spree.available_locales).to contain_exactly(:en, :de)
    end

    it 'leaves out shipped locales I18n does not accept' do
      allow(I18n).to receive(:available_locales).and_return(%i[en fr])

      expect(Spree.available_locales).to contain_exactly(:en, :fr)
    end
  end

  describe '.available_languages' do
    it 'lists only languages a store can be set to without a region' do
      allow(Spree).to receive(:available_locales).and_return(%i[en pt-BR de])

      expect(Spree.available_languages).to contain_exactly('en', 'de')
    end
  end

  describe '.t' do
    it 'translates within the spree scope' do
      expect(Spree.t(:foo)).to eq('bar')
    end

    it 'prepends the spree scope to a given scope' do
      expect(Spree.t(:foo, scope: 'bar')).to eq('bar within bar scope')
      expect(Spree.t(:foo, scope: [:bar])).to eq('bar within bar scope')
    end

    it 'ignores a spree scope the caller already passed' do
      expect(Spree.t(:foo, scope: :spree)).to eq('bar')
      expect(Spree.t(:foo, scope: 'spree')).to eq('bar')
    end

    it 'warns that it is deprecated' do
      expect(Spree::Deprecation).to receive(:warn).with(/Spree\.t is deprecated/)

      Spree.t(:foo)
    end

    it 'never returns HTML for a missing key' do
      expect(Spree.t(:missing_entry, default: 'Missing entry')).to eq('Missing entry')
    end
  end
end
