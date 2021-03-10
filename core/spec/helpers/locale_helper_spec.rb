require 'spec_helper'

describe Spree::LocaleHelper, type: :helper do
  let(:germany) { create(:country, name: 'Germany', iso: 'DE') }
  let(:eu_store) { create(:store, default_currency: 'EUR', default_locale: 'de', default_country: germany, supported_locales: 'fr,de') }
  let(:available_locales) { Spree::Store.available_locales }
  let(:supported_locales_for_all_stores) { [:en, :de, :fr] }

  describe '#all_locales_options' do
    it { expect(all_locales_options).to contain_exactly(['English (en)', 'en'], ['Deutsch (de)', 'de'], ['Français (fr)', 'fr']) }
  end

  describe '#all_locales_options shown in the active locale' do
    it { expect(all_locales_options(true)).to contain_exactly(['English (en)', 'en'], ['German (de)', 'de'], ['French (fr)', 'fr']) }
  end

  describe '#available_locales_options including one that can not be named by twitte_cldr' do
    before do
      create(:store, supported_locales: 'en,de,xx-XX')
    end

    it { expect(available_locales_options).to contain_exactly(['English (en)', 'en'], ['Deutsch (de)', 'de'], ['(xx-XX)', 'xx-XX']) }
  end

  describe '#locale_language_name' do
    context 'In native mode it returns the local translation' do
      it { expect(locale_language_name('zh-TW', false)).to eq('繁體中文 (zh-TW)') }
    end

    context 'in active locale mode it returns the english name' do
      it { expect(locale_language_name('zh-TW', true)).to eq('Traditional chinese (zh-TW)') }
    end

    context 'when passed a locale it does not reconise it returns the locale' do
      it { expect(locale_language_name('xx-XX', true)).to eq('(xx-XX)') }
    end
  end

  describe '#locale_language_name when using custom name' do
    before do
      create(:store, supported_locales: 'en,it', default_locale: 'it')
      I18n.backend.store_translations(:en,
                                      spree: {
                                        language_name_overide: {
                                          de: 'DE Germany (DEEE)',
                                          fr: 'FR FRANCE (FRRRR)'
                                        }
                                      })
    end

    context 'In native mode it returns the local translation' do
      it { expect(locale_language_name('de', false)).to eq('Deutsch (de)') }
    end

    context 'In active language mode with custom translation it return the custom translation' do
      it { expect(locale_language_name('de', true)).to eq('DE Germany (DEEE)') }
    end
  end

  describe '#supported_locales_options' do
    let(:current_store) { eu_store }

    it { expect(supported_locales_options).to contain_exactly(['Deutsch (de)', 'de'], ['Français (fr)', 'fr']) }
  end

  describe '#locale_presentation' do
    it { expect(locale_presentation(:fr)).to eq(['Français (fr)', 'fr']) }
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
