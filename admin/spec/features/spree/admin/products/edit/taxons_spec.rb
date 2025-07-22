require 'spec_helper'

describe 'Product Taxons', type: :feature, js: true do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let(:taxonomy) { store.taxonomies.find_or_create_by(name: 'Categories') }

  context 'managing taxons' do
    let!(:taxon_1) { create(:taxon, taxonomy: taxonomy) }
    let!(:taxon_2) { create(:taxon, name: 'Clothing', taxonomy: taxonomy) }
    let(:product) { create(:product, stores: [store]) }

    before do
      product.taxons << taxon_1
    end

    it 'allows an admin to manage taxons' do
      visit spree.edit_admin_product_path(product)

      expect(page).to have_content(taxon_1.pretty_name.to_s)
      expect(page).not_to have_content(taxon_2.pretty_name.to_s)

      tom_select(taxon_2.pretty_name, from: Spree.t(:taxonomies))

      within('#page-header') { click_button 'Update' }

      expect(page).to have_content(taxon_1.pretty_name.to_s)
      expect(page).to have_content(taxon_2.pretty_name.to_s)
    end
  end
end
