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

    context 'spree_localized_item_link' do
      let(:menu) { create(:menu, unique_code: 'main-123', store_id: current_store) }
      let(:product) { create(:product) }
      let(:taxon) { create(:taxon) }
      let(:item_url) { create(:menu_item, name: 'URL To Random Site', item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id, linked_resource_type: 'URL', destination: 'https://some-other-website.com') }
      let(:item_home) { create(:menu_item, name: 'Home', item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id, linked_resource_type: 'Home Page') }
      let(:item_product) { create(:menu_item, name: product.name, item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id, linked_resource_type: 'Spree::Product') }
      let(:item_taxon) { create(:menu_item, name: taxon.name, item_type: 'Link', menu_id: menu.id, parent_id: menu.root.id, linked_resource_type: 'Spree::Taxon') }

      context 'when the default language is passed in' do
        it 'returns / for home page' do
          expect(spree_localized_item_link(item_home)).to eq('/')
        end

        it 'returns /t/taxonomy-1/taxon-1 for a taxon' do
          item_taxon.update(linked_resource_id: taxon.id)
          expect(spree_localized_item_link(item_taxon)).to eq("#{item_taxon.destination}")
        end

        it 'returns /products/product-18-4225 for a product' do
          item_product.update(linked_resource_id: product.id)
          expect(spree_localized_item_link(item_product)).to eq("#{item_product.destination}")
        end

        it 'returns https://some-other-website.com for a URL' do
          expect(spree_localized_item_link(item_url)).to eq("#{item_url.destination}")
        end
      end

      context 'with the none default locale passed in (:fr)' do
        it 'returns /fr for home page' do
          expect(spree_localized_item_link(item_home)).to eq('/fr')
        end

        it 'returns /fr/t/taxonomy-1/taxon-1 for a taxon' do
          item_taxon.update(linked_resource_id: taxon.id)
          expect(spree_localized_item_link(item_taxon)).to eq("/fr#{item_taxon.destination}")
        end

        it 'returns /fr/products/product-18-4225 for a product' do
          item_product.update(linked_resource_id: product.id)
          expect(spree_localized_item_link(item_product)).to eq("/fr#{item_product.destination}")
        end

        it 'returns https://some-other-website.com for a URL' do
          expect(spree_localized_item_link(item_url)).to eq("#{item_url.destination}")
        end
      end
    end
  end
end
