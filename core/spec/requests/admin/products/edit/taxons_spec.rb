require 'spec_helper'

describe "Product Taxons" do
  stub_authorization!

  context "managing taxons" do
    it "should allow an admin to manage taxons", :js => true do
      taxon = create(:taxon, :name => 'Brands')
      taxon2 = create(:taxon, :taxonomy => taxon.taxonomy, :parent_id => taxon.id, :name => 'Apache')
      create(:product, :name => 'apache baseball cap', :sku => 'A100', :available_on => "2011-01-01 01:01:01")
      Spree::Product.update_all :count_on_hand => 10

      visit spree.admin_path
      click_link "Products"
      within('table.index tr:nth-child(2)') { click_link "Edit" }
      click_link "Taxons"
      find('#selected-taxons table.index thead th:nth-child(1)').text.should == 'Name'
      find('#selected-taxons table.index thead th:nth-child(2)').text.should == 'Path'
      find('#selected-taxons table.index tbody tr td').text.should == 'None.'
      fill_in "searchtext", :with => "a"

      within('#search_hits') do
        find('table.index thead tr th:nth-child(1)').text.should == 'Name'
        find('table.index thead tr th:nth-child(2)').text.should == 'Path'
        find('table.index thead tr th:nth-child(3)').text.should == 'Action'

        find('table.index tbody tr:nth-child(1) td:nth-child(1)').text.should == 'Brand'
        find('table.index tbody tr:nth-child(2) td:nth-child(1)').text.should == 'Brands'
        find('table.index tbody tr:nth-child(3) td:nth-child(1)').text.should == 'Apache'

        within('table.index tbody tr:nth-child(1)') { click_link "Select" }
      end

      click_link "Taxons"
      find('#selected-taxons table.index tbody tr td').text.should == 'Brand'
    end
  end
end
