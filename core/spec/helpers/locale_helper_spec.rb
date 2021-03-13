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

  describe '#all_locales_options with no set language argument passed returns each in its own language' do
    it { expect(all_locales_options).to contain_exactly(['English (en)', 'en'], ['Deutsch (de)', 'de'], ['Français (fr)', 'fr'], ["Italiano (it)", "it"]) }
  end

  describe '#all_locales_options with the argument passed to return language names in "en"' do
    it { expect(all_locales_options('en')).to contain_exactly(['English (en)', 'en'], ['German (de)', 'de'], ['French (fr)', 'fr'], ["Italiano (IT) - CUSTOM", "it"]) }
  end

  describe '#available_locales_options including one that can not be named by twitte_cldr' do
    before do
      create(:store, supported_locales: 'en,de,xx-XX')
    end

    it { expect(available_locales_options).to contain_exactly(['English (en)', 'en'], ['Deutsch (de)', 'de'], ['(xx-XX)', 'xx-XX']) }
  end

  describe '#locale_language_name' do
    context 'with no argumants passed returns the language name in its own language' do
      it { expect(locale_language_name('zh-TW')).to eq('繁體中文 (zh-TW)') }
    end

    context 'iwhen passed the argument of "en" it returns the English name' do
      it { expect(locale_language_name('zh-TW', 'en')).to eq('Traditional chinese (zh-TW)') }
    end

    context 'when passed a locale it does not reconise it returns the locale' do
      it { expect(locale_language_name('xx-XX', :en)).to eq('(xx-XX)') }
    end

    context 'when passed a locale with a custom overide it returns the custom name' do
      it { expect(locale_language_name('fr', :en)).to eq('French (fr)') }
    end

    context 'can handle string values' do
      it { expect(locale_language_name('it', 'en')).to eq('Italiano (IT) - CUSTOM') }
    end

    context 'can handle symbol values' do
      it { expect(locale_language_name(:'zh-TW', :en)).to eq('Traditional chinese (zh-TW)') }
    end
  end

  describe '#supported_locales_options' do
    let(:current_store) { eu_store }

    it { expect(supported_locales_options).to contain_exactly(['Deutsch (de)', 'de'], ['Français (fr)', 'fr'], ["Italiano (it)", "it"]) }
  end

  describe '#locale_presentation in show all mode' do
    it { expect(locale_presentation(:fr)).to eq(['Français (fr)', 'fr']) }
  end

  describe '#locale_presentation set to only show active_language' do
    before do
      Spree::Config[:only_show_languages_marked_as_active] = true
    end

    it { expect(locale_presentation(:fr)).to eq([]) }
    it { expect(locale_presentation(:en)).to eq(["English (en)", "en"]) }
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
