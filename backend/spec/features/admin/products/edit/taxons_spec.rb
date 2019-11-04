require 'spec_helper'

describe 'Product Taxons', type: :feature, js: true do
  stub_authorization!

  context 'managing taxons' do
    def selected_taxons
      find('#product_taxon_ids', visible: :hidden).value.split(',').map(&:to_i).uniq
    end

    it 'allows an admin to manage taxons' do
      taxon_1 = create(:taxon)
      taxon_2 = create(:taxon, name: 'Clothing')
      product = create(:product)
      product.taxons << taxon_1

      visit spree.admin_products_path
      within_row(1) { click_icon :edit }

      expect(page).to have_css('.select2-search-choice', exact_text: "#{taxon_1.parent.name} -> #{taxon_1.name}")
      expect(selected_taxons).to match_array([taxon_1.id])

      select2 'Clothing', from: 'Taxons'
      wait_for { !page.has_button?('Update') }
      click_button 'Update'
      expect(selected_taxons).to match_array([taxon_1.id, taxon_2.id])

      expect(page).to have_css('.select2-search-choice', text: taxon_1.name)
                  .and have_css('.select2-search-choice', text: taxon_2.name)
    end
  end
end
