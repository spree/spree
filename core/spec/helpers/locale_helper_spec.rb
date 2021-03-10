require 'spec_helper'

describe Spree::LocaleHelper, type: :helper do
  let(:germany) { create(:country, name: 'Germany', iso: 'GR') }
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
      create(:store, supported_locales: 'en')
    end

    it { expect(available_locales_options).to contain_exactly(['English (en)', 'en'], ['Deutsch (de)', 'de'], ['(xx-XX)', 'xx-XX']) }
  end

  describe '#available_locales_options including one have been given a custom name' do
    before do
      create(:store, supported_locales: 'en,it')
      create(:store, supported_locales: 'en')
      I18n.backend.store_translations(:it,
                                    spree: {
                                      language_name_overide: 'Sicilians Italian (SI)'
                                    })
    end

    it { expect(available_locales_options).to contain_exactly(['English (en)', 'en'], ['Sicilians Italian (SI)', 'it']) }
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
