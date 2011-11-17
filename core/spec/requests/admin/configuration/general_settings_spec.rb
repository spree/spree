require 'spec_helper'

describe "General Settings" do
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
      page.should have_content("Spree Demo Site")
      page.should have_content("demo.spreecommerce.com")
    end
  end

  context "editing general settings (admin)" do
    before(:each) do
      @configuration ||= Spree::AppConfiguration.find_or_create_by_name("Default configuration")
      Spree::Preference.create(:name => 'allow_ssl_in_production', :owner => @configuration, :value => '1')
      Spree::Preference.create(:name => 'site_url', :owner => @configuration, :value => "demo.spreecommerce.com")
      Spree::Preference.create(:name => 'allow_ssl_in_development_and_test', :owner => @configuration, :value => "0")
      Spree::Preference.create(:name => 'site_name', :owner => @configuration, :value => "Spree Demo Site")
    end

    it "should be able to update the site name" do
      pending "site name not being updated"

      click_link "admin_general_settings_link"
      page.should have_content("Edit General Settings")
      fill_in "app_configuration[preferred_site_name]", :with => "Spree Demo Site99"
      click_button "Update"

      page.should have_content("Spree Demo Site99")
    end
  end
end
