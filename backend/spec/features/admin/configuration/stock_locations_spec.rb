require 'spec_helper'

describe "Stock Locations" do
  stub_authorization!

  before(:each) do
    country = create(:country)
    visit spree.admin_path
    click_link "Configuration"
    click_link "Stock Locations"
  end

  it "can create a new stock location" do
    click_link "New Stock Location"
    fill_in "Name", with: "London"
    check "Active"
    click_button "Create"

    page.should have_content("successfully created")
    page.should have_content("London")
  end

  it "can delete an existing stock location", js: true do
    location = create(:stock_location)
    visit current_path

    find('#listing_stock_locations').should have_content("NY Warehouse")
    click_icon :trash
    page.driver.browser.switch_to.alert.accept
    # Wait for API request to complete.
    wait_for_ajax
    visit current_path 
    page.should have_content("NO STOCK LOCATIONS FOUND")
  end

  it "can update an existing stock location" do
    create(:stock_location)
    visit current_path

    page.should have_content("NY Warehouse")

    click_icon :edit
    fill_in "Name", with: "London"
    click_button "Update"

    page.should have_content("successfully updated")
    page.should have_content("London")
  end
end
