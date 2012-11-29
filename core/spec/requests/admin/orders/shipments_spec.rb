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
    within('table#listing_orders tbody tr:nth-child(1)') { click_link order.number }
  end

  it "should be able to create and list shipments for an order" do
    click_link "Shipments"

    click_on "New Shipment"
    check "inventory_units_1"
    click_button "Create"
    page.should have_content("successfully created!")
    order.reload
    order.shipments.count.should == 1

    shipment = order.shipments.last

    click_link "Shipments"
    find('table.index tr:nth-child(2) td:nth-child(1)').text.should == shipment.number
    find('table.index tr:nth-child(2) td:nth-child(5)').text.should == "Pending"

    within('table.index tr:nth-child(2) td:nth-child(7)') { click_link "Edit" }
    page.should have_content("Shipment ##{shipment.number}")
  end

end
