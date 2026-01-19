require 'spec_helper'

RSpec.describe 'Featured taxon', type: :feature do
  let(:store) { Spree::Store.default }
  let!(:products) { create_list(:product, 10, price: 5.00, stores: [store]) }
  let(:categories_taxonomy) { store.taxonomies.find_by(name: 'Categories') }
  let(:taxon) { create(:taxon, taxonomy: categories_taxonomy) }
  let(:section) { Spree::PageSections::FeaturedTaxon.create(preferred_taxon_id: taxon&.id, pageable: Spree::Page.find_by(name: 'Homepage')) }

  before do
    store.taxons.automatic.delete_all
    taxon.products << products if taxon.present?
    visit spree.page_section_path(section.id)
  end

  describe 'swiper' do
    it 'renders proper turbo frame id' do
      expect(page).to have_css("turbo-frame[id='section-#{section.id}']")
    end

    it 'renders product names' do
      products.each do |product|
        expect(page).to have_content(product.name)
      end
    end

    it 'renders header' do
      expect(page).to have_content(section.preferred_heading)
    end

    it 'renders `Explore category` button' do
      expect(page).to have_content('Explore category')
    end

    context 'when max products is less than products count' do
      before do
        section.update(preferred_max_products_to_show: 5)
        visit spree.page_section_path(section.id)
      end

      it 'renders only selected products' do
        products.first(5).each do |product|
          expect(page).to have_content(product.name)
        end

        products.last(5).each do |product|
          expect(page).not_to have_content(product.name)
        end
      end
    end

    context 'when taxon is not selected' do
      let(:taxon) { nil }

      it 'does not throw error' do
        expect(page).to have_content(section.preferred_heading)
        expect(page).not_to have_content(section.preferred_button_text)

        products.each do |product|
          expect(page).not_to have_content(product.name)
        end
      end
    end
  end
end
