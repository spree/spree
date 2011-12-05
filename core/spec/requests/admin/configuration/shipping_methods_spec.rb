require 'spec_helper'

describe "Shipping Methods" do
  before(:each) do
    Factory(:global_zone)
    sign_in_as!(Factory(:admin_user))
    visit spree.admin_path
    click_link "Configuration"
  end

  context "show" do
    it "should display exisiting shipping methods" do
      2.times { Factory(:shipping_method) }
      click_link "Shipping Methods"

      find('table#listing_shipping_methods tbody tr:nth-child(1) td:nth-child(1)').text.should == "UPS Ground"
      find('table#listing_shipping_methods tbody tr:nth-child(1) td:nth-child(2)').text.should == "GlobalZone"
      find('table#listing_shipping_methods tbody tr:nth-child(1) td:nth-child(3)').text.should == "Flat Rate (per order)"
      find('table#listing_shipping_methods tbody tr:nth-child(1) td:nth-child(4)').text.should == "Both"
    end
  end

  context "create" do
    it "should be able to create a new shipping method" do
      click_link "Shipping Methods"
      click_link "admin_new_shipping_method_link"
      page.should have_content("New Shipping Method")
      fill_in "shipping_method_name", :with => "bullock cart"
      click_button "Create"
      page.should have_content("successfully created!")
      page.should have_content("Editing Shipping Method")
    end
  end

  # Regression test for #825
  context "edit" do
    before do
      Factory(:shipping_method)
    end

    it "should be able to edit an existing shipping method" do
      click_link "Shipping Methods"
      within("#listing_shipping_methods") do
        click_link "Edit"
      end
      select "Flat Percent", :from => "Calculator"
      click_button "Update"
      page!
    end
  end
end
