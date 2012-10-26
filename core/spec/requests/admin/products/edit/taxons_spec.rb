require 'spec_helper'

describe "Product Taxons" do
  stub_authorization!

  context "managing taxons" do
    def selected_taxons
      find("#product_taxon_ids").value.split(',').map(&:to_i)
    end

    it "should allow an admin to manage taxons", :js => true do
      taxon_1 = create(:taxon)
      taxon_2 = create(:taxon, :name => 'Clothing')
      product = create(:product)
      product.taxons << taxon_1

      visit spree.admin_path
      click_link "Products"
      within("table.index") do
        click_icon :edit
      end

      find(".select2-search-choice").text.should == taxon_1.name
      selected_taxons.should =~ [taxon_1.id]
      select2("#product_taxons_field", "Clothing")
      click_button "Update"
      selected_taxons.should =~ [taxon_1.id, taxon_2.id]

      # Regression test for #2139
      all("#s2id_product_taxon_ids .select2-search-choice").count.should == 2
    end
  end
end
