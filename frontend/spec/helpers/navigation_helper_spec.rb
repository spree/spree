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

    describe '#spree_nav_link_tag' do
      let(:store) { create(:store) }
      let(:menu) { create(:menu, store: store) }
      let(:locale_param) { 'en' }

      include Spree::CurrencyHelper
      include Spree::LocaleHelper

      context 'when link is passed with no arguments' do
        let(:menu_item) { create(:menu_item, menu: menu, destination: 'https://my-website.com') }

        it 'returns the link destination with no unexpected attributes' do
          expect(spree_nav_link_tag(menu_item)).to eq('<a href="https://my-website.com">Link To Somewhere</a>')
        end
      end

      context 'when link is passed with setting to open in a new window' do
        let(:menu_item) { create(:menu_item, menu: menu, destination: 'https://my-website.com', new_window: true) }

        it 'returns the link destination with target="_blank" rel="noopener noreferrer"' do
          expect(spree_nav_link_tag(menu_item)).to eq('<a target="_blank" rel="noopener noreferrer" href="https://my-website.com">Link To Somewhere</a>')
        end
      end

      context 'when link is passed with setting to open in a new window, and passed custom attributes' do
        let(:menu_item) { create(:menu_item, menu: menu, destination: 'https://my-website.com', new_window: true) }

        it 'returns the link destination with a full set of cutstom attributes' do
          expect(spree_nav_link_tag(menu_item, { class: 'custom-class', id: 'custonId', target: '_not_so_blank', rel: 'related', data: 'custom-data', aria: 'custom-aria' })).
            to eq('<a target="_not_so_blank" rel="related" class="custom-class" id="custonId" data="custom-data" aria="custom-aria" href="https://my-website.com">Link To Somewhere</a>')
        end
      end

      context 'when passed a block' do
        let(:menu_item) { create(:menu_item, menu: menu, destination: 'https://my-website.com', new_window: true) }

        it 'returns the link containing the contents of the block' do
          expect(spree_nav_link_tag(menu_item) { content_tag :span, 'Hello' }).
            to eq('<a target="_blank" rel="noopener noreferrer" href="https://my-website.com"><span>Hello</span></a>')
        end
      end
    end
  end
end
