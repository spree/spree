require 'spec_helper'

describe Spree::LocaleHelper, type: :helper do
  let(:germany) { create(:country, name: 'Germany', iso: 'GR') }
  let(:eu_store) { create(:store, default_currency: 'EUR', default_locale: 'de', default_country: germany, supported_locales: 'fr,de') }
  let(:available_locales) { Spree::Store.available_locales }
  let(:supported_locales_for_all_stores) { [:en, :de, :fr] }

  before do
    I18n.backend.store_translations(:de,
      spree: {
        i18n: {
          this_file_language: 'Deutsch (DE)'
        }
      })
    I18n.backend.store_translations(:fr,
      spree: {
        i18n: {
          this_file_language: 'Français (FR)'
        }
      })
  end

  describe '#all_locales_options' do
    it { expect(all_locales_options).to contain_exactly(['EN — English', 'en'], ['DE — Deutsch', 'de'], ['FR — Français', 'fr']) }
  end

  describe '#available_locales_options' do
    before do
      store = create(:store, default: true, supported_locales: 'en,de', default_locale: 'en')
      Spree::Store.where.not(id: store.id).update_all(default: false)
      Rails.cache.clear
    end

    it { expect(available_locales_options).to contain_exactly(['EN — English', 'en'], ['DE — Deutsch', 'de']) }
  end

  describe '#supported_locales_options' do
    let(:current_store) { eu_store }

    it { expect(supported_locales_options).to contain_exactly(['DE — Deutsch', 'de'], ['FR — Français', 'fr']) }
  end

  describe '#translation_locales_options' do
    subject { translation_locales_options }

    let(:current_store) { eu_store }

    it 'returns the full canonical translation-locale set in order' do
      expect(subject.map(&:last)).to eq(Spree::Locales::ALL)
    end

    it 'returns [name, code] pairs suitable for a select' do
      expect(subject).to all(be_an(Array).and(have_attributes(size: 2)))
      expect(subject).to include(['DE — Deutsch', 'de'], ['FR — Français', 'fr'])
    end

    it 'offers regional variants a store may not yet use' do
      expect(subject.map(&:last)).to include('pt-BR', 'pt-PT', 'zh-CN', 'es-MX', 'en-GB')
    end

    it 'is independent of the store\'s configured supported_locales' do
      # eu_store only supports fr,de — the picker still offers everything.
      expect(subject.map(&:last)).to include('en', 'ja', 'ar')
    end
  end

  describe '#locale_presentation' do
    it { expect(locale_presentation(:fr)).to eq(['FR — Français', 'fr']) }

    it 'returns the locale when no translation exists' do
      expect(locale_presentation(:klingon)).to eq(['KLINGON', 'klingon'])
    end
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
