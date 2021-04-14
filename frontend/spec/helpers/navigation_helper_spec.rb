require 'spec_helper'

module Spree
  describe NavigationHelper, type: :helper do
    include Spree::CurrencyHelper
    include Spree::LocaleHelper

    describe '#spree_navigation_data' do
      let!(:current_store) { create(:store) }

      context 'fetch via locale' do
        before { I18n.locale = :fr }

        after { I18n.locale = :en }

        it { expect(spree_navigation_data.first[:title]).to eq('Femmes') }
      end

      context 'fetch via store code' do
        before { current_store.update(code: 'fr') }

        it { expect(spree_navigation_data.first[:title]).to eq('Femmes') }
      end

      context 'fallback to default' do
        it { expect(spree_navigation_data.first[:title]).to eq('Women') }
      end
    end

    describe '#should_render_internationalization_dropdown?' do
      context 'store with multiple currencies' do
        let(:current_store) { create(:store, supported_currencies: 'EUR,USD') }

        it { expect(should_render_internationalization_dropdown?).to be_truthy }
      end

      context 'store with multiple locales' do
        let(:current_store) { create(:store, supported_locales: 'en,fr') }

        it { expect(should_render_internationalization_dropdown?).to be_truthy }
      end

      context 'store with multiple currencies and locales' do
        let(:current_store) { create(:store, supported_currencies: 'EUR,USD', supported_locales: 'en,fr') }

        it { expect(should_render_internationalization_dropdown?).to be_truthy }
      end

      context 'store with single currency and locale' do
        let(:current_store) { create(:store, supported_currencies: nil, supported_locales: nil) }

        it { expect(should_render_internationalization_dropdown?).to be_falsey }
      end
    end
  end
end
