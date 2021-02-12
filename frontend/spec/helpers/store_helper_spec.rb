require 'spec_helper'

module Spree
  describe StoreHelper, type: :helper do
    let(:germany) { create(:country, name: 'Germany', iso: 'GR') }
    let(:eu_store) { create(:store, default_currency: 'EUR', default_locale: 'de', default_country: germany) }

    before do
      I18n.backend.store_translations(:de,
        spree: {
          i18n: {
            this_file_language: 'Deutsch (DE)'
          }
        })
    end

    describe '#stores' do
      before { create_list(:store, 3) }

      it { expect(stores.count).to eq(Spree::Store.count) }
      it { expect(stores).to eq(Spree::Store.order(:id)) }
    end

    describe '#store_country_iso' do
      let(:store_with_default_country) { build(:store, default_country: germany) }

      it { expect(store_country_iso(eu_store)).to eq('gr') }
      it { expect(store_country_iso(Spree::Store.default)).to be_nil }
    end

    describe '#store_currency_symbol' do
      it { expect(store_currency_symbol(Spree::Store.default)).to eq('$') }
      it { expect(store_currency_symbol(eu_store)).to eq('€') }
    end

    describe '#store_locale_name' do
      it { expect(store_locale_name(Spree::Store.default)).to eq('English (US)') }
      it { expect(store_locale_name(eu_store)).to eq('Deutsch (DE)') }
    end
  end
end
