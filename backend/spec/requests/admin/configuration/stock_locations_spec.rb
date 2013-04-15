require 'spec_helper'

describe "Stock Locations" do
  stub_authorization!

  before(:each) do
    country = create(:country)
    Spree::Config[:default_country_id] = country.id
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
    create(:stock_location)
    visit current_path

    page.should have_content("NY Warehouse")

    click_icon :trash
    page.driver.browser.switch_to.alert.accept
    visit current_path
    page.should have_content("successfully removed")
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

  context "tranferring stock", js: true do
    let!(:la) { create(:stock_location_with_items, name: "Los Angeles") }
    let!(:boston) { create(:stock_location_with_items, name: "Boston") }

    it "can transfer stock between two locations" do
      visit current_path
      variant = la.stock_items.first.variant
      la.stock_item(variant).count_on_hand.should == 10
      boston.stock_item(variant).count_on_hand.should == 0

      select2 "Los Angeles", from: "Transfer From"
      select2 "Boston", from: "Transfer To"
      select2 "#{variant.name}", from: "Variant"
      fill_in "Quantity", with: 5

      click_button "Transfer Stock"

      page.should have_content("successfully transferred")
      la.reload.stock_item(variant).count_on_hand.should == 5
      boston.reload.stock_item(variant).count_on_hand.should == 5
    end

    it "shows an error when failing to transfer stock between two locations" do
      Spree::StockMovement.any_instance.stub(save: false)
      visit current_path
      variant = la.stock_items.first.variant
      la.stock_item(variant).count_on_hand.should == 10
      boston.stock_item(variant).count_on_hand.should == 0

      select2 "Los Angeles", from: "Transfer From"
      select2 "Boston", from: "Transfer To"
      select2 "#{variant.name}", from: "Variant"

      click_button "Transfer Stock"

      page.should have_content("problem transferring")
      la.reload.stock_item(variant).count_on_hand.should == 10
      boston.reload.stock_item(variant).count_on_hand.should == 0
    end
  end
end
