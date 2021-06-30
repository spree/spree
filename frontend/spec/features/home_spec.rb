require 'spec_helper'

describe 'Visiting the homepage', type: :feature, js: true do
  let!(:store) { Spree::Store.default }
  let!(:taxonomy_a) { create(:taxonomy, name: 'Bestsellers') }
  let!(:bestsellers) { taxonomy_a.root.children.create(name: 'Bestsellers') }
  let!(:taxonomy_b) { create(:taxonomy, name: 'Trending') }
  let!(:trending) { taxonomy_b.root.children.create(name: 'Trending') }
  let!(:product_a) { create(:product, name: 'Superman T-Shirt', taxons: [bestsellers]) }
  let!(:product_b) { create(:product, name: 'Batman Socks', taxons: [bestsellers]) }

  context 'when taxon bestsellers exists and has products available in current store currency' do
    before do
      visit spree.root_path + '#BestSellersTaxonProductCarousel'
    end

    it 'loads the carousel with the products displayed' do
      within '#BestSellersTaxonProductCarousel' do
        expect(page).to have_content('BESTSELLERS')
        expect(page).to have_content('Superman T-Shirt')
        expect(page).to have_content('Batman Socks')
      end
    end

    it 'loads carousel items in order of position' do
      within ".carouselItem:nth-child(1)" do
        expect(page).to have_content('Superman T-Shirt')
      end

      within ".carouselItem:nth-child(2)" do
        expect(page).to have_content('Batman Socks')
      end
    end
  end

  context 'when products exist but not available in the current store currency' do
    before do
      store.update(default_currency: 'GBP')
      visit spree.root_path + '#BestSellersTaxonProductCarousel'
    end

    it 'the carousel is not loaded' do
        expect(page).not_to have_content('BESTSELLERS')
        expect(page).not_to have_content('Superman T-Shirt')
        expect(page).not_to have_content('Batman Socks')
    end
  end
end
