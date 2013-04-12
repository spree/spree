require 'spec_helper'

describe "Stock Locations" do
  stub_authorization!
  let!(:stock_location) { create(:stock_location, :country => nil) }

  before(:each) do
    # HACK: To work around no email prompting on check out
    Spree::Order.any_instance.stub(:require_email => false)
    create(:payment_method, :environment => 'test')

    visit spree.admin_path
    click_link "Configuration"
  end


  context "show" do
    it "should display exisiting stock locations" do
      click_link "Stock Locations"

      within_row(1) do
        column_text(1).should == stock_location.name
        column_text(2).should == "active"
        column_text(3).should == "Stock Movements"
      end
    end
  end

  context "create" do
    it "should be able to create a new stock location" do
      click_link "Stock Locations"
      click_link "admin_new_stock_location"
      page.should have_content("New Stock Location")
      fill_in "stock_location_name", :with => "bullock stock location"
      click_button "Create"
      page.should have_content("successfully created!")
      page.should have_content("Editing Shipping Method")
    end
  end

  # Regression test for #2818
  context "update" do
    it "can change a stock location with no associated country" do
      click_link "Stock Locations"
      within("#listing_stock_locations") do
        click_icon :edit
      end

      select('United States', :from => 'Country')

      click_button "Update"
      page.should have_content("successfully updated!")
    end
  end

end
