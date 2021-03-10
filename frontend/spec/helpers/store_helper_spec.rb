require 'spec_helper'

module Spree
  describe StoreHelper, type: :helper do
    let(:germany) { build(:country, name: 'Germany', iso: 'GR') }
    let(:eu_store) { build(:store, url: 'eu.spreecommerce.org', default_currency: 'EUR', default_locale: 'de', default_country: germany) }

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
      it { expect { store_country_iso(nil) }.not_to raise_error }
    end

    describe '#store_currency_symbol' do
      it { expect(store_currency_symbol(Spree::Store.default)).to eq('$') }
      it { expect(store_currency_symbol(eu_store)).to eq('€') }
      it { expect { store_currency_symbol(nil) }.not_to raise_error }
    end

    describe '#store_locale_name' do
      it { expect(store_locale_name(Spree::Store.default)).to eq('English (US)') }
      it { expect(store_locale_name(eu_store)).to eq('Deutsch (DE)') }
      it { expect { store_locale_name(nil) }.not_to raise_error }
    end

    describe '#store_link' do
      it { expect(store_link(eu_store)).to eq('<a href="https://eu.spreecommerce.org">Deutsch (DE) (€)</a>') }
      it { expect(store_link(eu_store, class: 'some-class')).to eq('<a class="some-class" href="https://eu.spreecommerce.org">Deutsch (DE) (€)</a>') }
      it { expect { store_link(nil) }.not_to raise_error }
    end

    describe '#should_render_store_chooser?' do
      context 'enabled' do
        before { Spree::Config.show_store_selector = true }

        after { Spree::Config.show_store_selector = false }

        context 'with 1 store' do
          it { expect(should_render_store_chooser?).to be_falsey }
        end

        context 'with multiple stores' do
          before { create_list(:store, 2) }

          it { expect(should_render_store_chooser?).to be_truthy }
        end
      end

      context 'disabled' do
        it { expect(should_render_store_chooser?).to be_falsey }
      end
    end
  end
end
