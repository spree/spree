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

  describe '.locale_for_language' do
    let(:locales) { %i[en de de-CH zh-TW zh-CN] }

    it 'picks the language itself when Spree ships it' do
      expect(Spree.locale_for_language('de', locales)).to eq('de')
    end

    it "picks a regional variant when Spree ships the language only by region" do
      expect(Spree.locale_for_language('zh', locales)).to eq('zh-CN')
    end

    it 'returns nothing for a language Spree does not ship' do
      expect(Spree.locale_for_language('sq', locales)).to be_nil
    end
  end

  describe '.t' do
    # The test app raises on this warning so Spree's own code never calls Spree.t.
    before { allow(Spree::Deprecation).to receive(:warn) }

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
