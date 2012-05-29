require 'spec_helper'

describe "General Settings" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Configuration"
    click_link "General Settings"
  end

  context "visiting general settings (admin)" do
    it "should be have the right content" do
      page.should have_content("General Settings")
      page.should have_content("Site Name")
      page.should have_content("Site URL")
      page.should have_content("Spree demo site")
      page.should have_content("demo.spreecommerce.com")
    end
  end

  context "editing general settings (admin)" do
    it "should be able to update the site name" do
      click_link "admin_general_settings_link"
      page.should have_content("Edit General Settings")
      fill_in "site_name", :with => "Spree Demo Site99"
      click_button "Update"

      page.should have_content("Spree Demo Site99")
    end
  end
end
