require 'spec_helper'

describe Spree::LocaleHelper, type: :helper do
  let(:germany) { create(:country, name: 'Germany', iso: 'DE') }
  let(:eu_store) { create(:store, default_currency: 'EUR', default_locale: 'de', default_country: germany, supported_locales: 'fr,de') }
  let(:available_locales) { Spree::Store.available_locales }
  let(:supported_locales_for_all_stores) { [:en, :de, :fr] }

  before do
    I18n.backend.store_translations(:de,
      spree: {
        i18n: {
          this_file_language: 'Deutsch (de)'
        }
      })
    I18n.backend.store_translations(:fr,
      spree: {
        i18n: {
          this_file_language: 'Français (fr)'
        }
      })
  end

  describe '#all_locales_options' do
    it { expect(all_locales_options).to contain_exactly(['English (en)', 'en'], ['Deutsch (de)', 'de'], ['Français (fr)', 'fr']) }
  end

  describe '#available_locales_options' do
    before do
      create(:store, supported_locales: 'en,de')
      create(:store, supported_locales: 'en')
    end

    it { expect(available_locales_options).to contain_exactly(['English (en)', 'en'], ['Deutsch (de)', 'de']) }
  end

  describe '#supported_locales_options' do
    let(:current_store) { eu_store }

    it { expect(supported_locales_options).to contain_exactly(['Deutsch (de)', 'de'], ['Français (fr)', 'fr']) }
  end

  describe '#locale_presentation' do
    it { expect(locale_presentation(:fr)).to eq( ['Français (fr)', 'fr']) }
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
