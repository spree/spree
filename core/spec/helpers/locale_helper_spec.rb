require 'spec_helper'

describe Spree::LocaleHelper, type: :helper do
  let(:germany) { create(:country, name: 'Germany', iso: 'DE') }
  let(:eu_store) { create(:store, default_currency: 'EUR', default_locale: 'de', default_country: germany, supported_locales: 'fr,de,it') }
  let(:available_locales) { Spree::Store.available_locales }
  let(:supported_locales_for_all_stores) { [:en, :de, :fr, :it] }

  before do
    I18n.backend.store_translations(:en,
                                    spree: {
                                      active_language: true,
                                      language_name_overide: {
                                        it: 'Italiano (IT) - CUSTOM'
                                      }
                                    })
  end

  describe '#all_locales_options with no set language argument passed returns each in its native language' do
    it { expect(all_locales_options).to contain_exactly(['English (en)', 'en'], ['Deutsch (de)', 'de'], ['Français (fr)', 'fr'], ['Italiano (it)', 'it']) }
  end

  describe '#all_locales_options with the argument passed to return language names in "en"' do
    it { expect(all_locales_options('en')).to contain_exactly(['English (en)', 'en'], ['German (de)', 'de'], ['French (fr)', 'fr'], ['Italiano (IT) - CUSTOM', 'it']) }
  end

  describe '#available_locales_options including one that can not be named by twitte_cldr' do
    before do
      create(:store, supported_locales: 'en,de,xx-XX')
    end

    it { expect(available_locales_options).to contain_exactly(['English (en)', 'en'], ['Deutsch (de)', 'de'], ['(xx-XX)', 'xx-XX']) }
  end

  describe '#localized_language_name' do
    context 'passing in "zh-TW" with no other arguments passed, it returns the language name in its native language' do
      it { expect(localized_language_name('zh-TW')).to eq('繁體中文 (zh-TW)') }
    end

    context 'when passed "zh-TW" the argument of "en" it returns the English translation of the locale name' do
      it { expect(localized_language_name('zh-TW', 'en')).to eq('Traditional chinese (zh-TW)') }
    end

    context 'when passed "xx-XX" a locale it does not recognise it returns the same locale' do
      it { expect(localized_language_name('xx-XX', :en)).to eq('(xx-XX)') }
    end

    context 'when passed "xx-XX" a locale it does not recognise in a requested language it does not recognise "xx-XX it returns the locale"' do
      it { expect(localized_language_name('xx-XX', 'xx-XX')).to eq('(xx-XX)') }
    end

    context 'when passed "it" requested in "en" a locale that has a custom locale it returns the locale name set in en.yml' do
      it { expect(localized_language_name('it', 'en')).to eq('Italiano (IT) - CUSTOM') }
    end

    context 'can handle string values' do
      it { expect(localized_language_name('fr', 'fr')).to eq('Français (fr)') }
    end

    context 'can handle symbol values' do
      it { expect(localized_language_name(:'zh-TW', :en)).to eq('Traditional chinese (zh-TW)') }
    end

    context 'if it does not recognize "it" in the the requested language of "de-XX", it uses the fallback "de"' do
      it { expect(localized_language_name(:'it', 'de-XX')).to eq('Italienisch (it)') }
    end

    context 'if you request "es-XX" a language it does not know how to name, as a last resort, it will use the fallback "es" for the language you required' do
      it { expect(localized_language_name(:'es-XX', 'de')).to eq('Spanisch (es-XX)') }
    end
  end

  describe '#supported_locales_options' do
    let(:current_store) { eu_store }

    it { expect(supported_locales_options).to contain_exactly(['Deutsch (de)', 'de'], ['Français (fr)', 'fr'], ['Italiano (it)', 'it']) }
  end

  describe '#locale_presentation in show all mode' do
    it { expect(locale_presentation(:fr)).to eq(['Français (fr)', 'fr']) }
  end

  describe '#locale_presentation set to only show active_language' do
    before do
      Spree::Config[:only_show_languages_marked_as_active] = true
    end

    it { expect(locale_presentation(:fr)).to eq([]) }
    it { expect(locale_presentation(:en)).to eq(['English (en)', 'en']) }
  end

  describe '#should_render_locale_dropdown?' do
    context 'store with multiple locales' do
      let(:current_store) { eu_store }

      it { expect(should_render_locale_dropdown?).to be_truthy }
    end

    context 'store with single locale' do
      let(:current_store) { create(:store, supported_locales: 'en', default_locale: 'en') }

      it { expect(should_render_locale_dropdown?).to be_falsey }
    end
  end
end
