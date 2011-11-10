require 'spec_helper'

describe "Inventory Settings" do
  context "changing settings" do
    before(:each) do
      @configuration ||= Spree::AppConfiguration.find_or_create_by_name("Default configuration")
      Spree::Config.set :allow_backorders => true
      visit admin_path
      click_link "Configuration"
      click_link "Inventory Settings"
    end

    it "should have the right content" do
      page.should have_content("Inventory Settings")
      page.should have_content("Products with a zero inventory will be displayed")
      page.should have_content("Backordering allowed")
    end

    it "should be able to toggle displaying zero stock products" do
      pending "stub config"

      click_link "admin_inventory_settings_link"
      uncheck "preferences_show_zero_stock_products"
      click_button "Update"

      page.should have_content("Products with a zero inventory will not be displayed")
    end

    it "should be able to toggle allowing backorders" do
      pending "stub config"

      click_link "admin_inventory_settings_link"
      uncheck "preferences_allow_backorders"
      click_button "Update"

      page.should have_content("Backordering not allowed")
    end
  end
end
