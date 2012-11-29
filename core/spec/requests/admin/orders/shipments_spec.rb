require 'spec_helper'

describe "Shipments" do
  stub_authorization!

  let!(:order) { OrderWalkthrough.up_to(:complete) }

  before(:each) do
    # Clear all the shipments and then re-create them in this test

    order.shipments.delete_all
    reset_spree_preferences do |config|
      config.allow_backorders = true
    end

    visit spree.admin_path
    click_link "Orders"
    within_row(1) { click_link order.number }
  end

  it "should be able to create and list shipments for an order", :js => true do

    click_link "Shipments"

    click_on "New Shipment"
    check "inventory_units_1"
    click_button "Create"
    page.should have_content("successfully created!")
    order.reload
    order.shipments.count.should == 1

    click_link "Shipments"
    shipment = order.shipments.last

    within_row(1) do
      column_text(1).should == shipment.number
      column_text(5).should == "Pending"
      click_icon(:edit)
    end

    page.should have_content("##{shipment.number}")
  end

end
