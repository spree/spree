require 'spec_helper'

describe "General Settings" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Configuration"
    click_link "General Settings"
  end

  context "visiting general settings (admin)" do
    it "should have the right content" do
      page.should have_content("General Settings")
      find("#site_name").value.should == "Spree Demo Site"
      find("#site_url").value.should == "demo.spreecommerce.com"
    end
  end

  context "editing general settings (admin)" do
    it "should be able to update the site name" do
      fill_in "site_name", :with => "Spree Demo Site99"
      click_button "Update"

      page.should have_content(I18n.t(:general_settings_updated))
      find("#site_name").value.should == "Spree Demo Site99"
    end
  end
end
