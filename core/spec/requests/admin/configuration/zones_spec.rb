require 'spec_helper'

describe "Zones" do
  before(:each) do
    Spree::Zone.delete_all
    visit spree.admin_path
    click_link "Configuration"
  end

  context "show" do
    it "should display existing zones" do
      create(:zone, :name => "eastern", :description => "zone is eastern")
      create(:zone, :name => "western", :description => "cool san fran")
      click_link "Zones"

      find('table#listing_zones tbody tr:nth-child(1) td:nth-child(1)').text.should == "eastern"
      find('table#listing_zones tbody tr:nth-child(2) td:nth-child(1)').text.should == "western"

      click_link "zones_order_by_description_title"
      find('table#listing_zones tbody tr:nth-child(1) td:nth-child(1)').text.should == "western"
      find('table#listing_zones tbody tr:nth-child(2) td:nth-child(1)').text.should == "eastern"
    end
  end

  context "create" do
    it "should allow an admin to create a new zone" do
      click_link "Zones"
      click_link "admin_new_zone_link"
      page.should have_content("New Zone")
      fill_in "zone_name", :with => "japan"
      fill_in "zone_description", :with => "japanese time zone"
      click_button "Create"
      page.should have_content("successfully created!")
    end
  end
end
