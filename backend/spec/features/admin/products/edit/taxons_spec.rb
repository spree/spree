require 'spec_helper'

describe 'Product Taxons', type: :feature, js: true do
  stub_authorization!

  after do
    Capybara.ignore_hidden_elements = true
  end

  before do
    Capybara.ignore_hidden_elements = false
  end

  context 'managing taxons' do
    def selected_taxons
      find('#product_taxon_ids').value.split(',').map(&:to_i).uniq
    end

    it 'allows an admin to manage taxons' do
      taxon_1 = create(:taxon)
      taxon_2 = create(:taxon, name: 'Clothing')
      product = create(:product)
      product.taxons << taxon_1

      visit spree.admin_products_path
      within_row(1) { click_icon :edit }

      expect(find('.select2-search-choice').text).to eq("#{taxon_1.parent.name} -> #{taxon_1.name}")
      expect(selected_taxons).to match_array([taxon_1.id])

      select2_search 'Clothing', from: 'Taxons'
      click_button 'Update'
      expect(selected_taxons).to match_array([taxon_1.id, taxon_2.id])

      # Regression test for #2139
      sleep(1)
      expect(first('.select2-search-choice', text: taxon_1.name)).to be_present
      expect(first('.select2-search-choice', text: taxon_2.name)).to be_present
    end
  end
end
