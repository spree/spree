require 'spec_helper'

module Spree
  describe NavigationHelper, type: :helper do
    include Spree::CurrencyHelper
    include Spree::LocaleHelper

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
