require 'spec_helper'

describe 'Product Taxons', type: :feature, js: true do
  stub_authorization!

  context 'managing taxons' do
    it 'allows an admin to manage taxons' do
      taxon_1 = create(:taxon)
      taxon_2 = create(:taxon, name: 'Clothing')
      product = create(:product)
      product.taxons << taxon_1

      visit spree.admin_products_path
      within_row(1) { click_icon :edit }

      expect(page).to have_css('.select2-selection__choice', text: "#{taxon_1.parent.name} -> #{taxon_1.name}")

      select2_open label: 'Taxons'
      select2_search 'Clothing', from: 'Taxons'
      select2_select 'Clothing', from: 'Taxons', match: :first
      wait_for { !page.has_button?('Update') }
      click_button 'Update'

      expect(page).to have_css('.select2-selection__choice', text: taxon_1.name).
                  and have_css('.select2-selection__choice', text: taxon_2.name)
    end
  end
end
