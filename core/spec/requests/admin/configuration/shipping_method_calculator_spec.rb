require 'spec_helper'

describe "ShipmentsCalculator" do
  stub_authorization!

  context "shows the right amount for each shipment", :js => true do
    before do
      reset_spree_preferences do |config|
        config.allow_backorders = true
      end

      order = OrderWalkthrough.up_to(:complete)
      variant = Factory(:variant, :count_on_hand => 10)
      order.add_variant(variant)

      # We will re-create the shipments within the test
      order.shipments.delete_all

      visit spree.admin_path
      click_link "Orders"
      within('table#listing_orders tbody tr:nth-child(1)') { click_link order.number }
    end

    specify do
      click_link "Shipments"
      click_on "New Shipment"
      check "inventory_units_1"
      click_button "Create"

      click_link "Shipments"
      click_on "New Shipment"
      check "inventory_units_2"
      click_button "Create"

      click_link "Shipments"
      Spree::Order.first.shipments.first.cost.should == 10
      Spree::Order.first.shipments.last.cost.should == 10
    end
  end
end
