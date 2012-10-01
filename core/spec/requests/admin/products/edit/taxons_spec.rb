require 'spec_helper'

describe "Product Taxons" do
  stub_authorization!

  context "managing taxons" do
    def selected_taxons
      find("#product_taxon_ids").value.map(&:to_i)
    end

    it "should allow an admin to manage taxons", :js => true do
      taxon_1 = create(:taxon)
      taxon_2 = create(:taxon, :name => 'Clothing')
      product = create(:product)
      product.taxons << taxon_1

      visit spree.admin_path
      click_link "Products"
      within("table.index") do
        click_icon(:edit)
      end

      selected_taxons.should =~ [taxon_1.id]
      select "Clothing", :from => "Taxons"
      click_button "Update"
      selected_taxons.should =~ [taxon_1.id, taxon_2.id]
    end
  end
end
