require 'spec_helper'

describe "Product Taxons" do
  stub_authorization!

  after do
    Capybara.ignore_hidden_elements = true
  end

  before do
    Capybara.ignore_hidden_elements = false
  end

  context "managing taxons" do
    def selected_taxons
      find("#product_taxon_ids").value.split(',').map(&:to_i).uniq
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

      select2_search "Clothing", :from => "Taxons"
      click_button "Update"
      selected_taxons.should =~ [taxon_1.id, taxon_2.id]

      # Regression test for #2139
      sleep(1)
      expect(first(".select2-search-choice", text: taxon_1.name)).to be_present
      expect(first(".select2-search-choice", text: taxon_2.name)).to be_present
    end
  end
end
