require 'spec_helper'

describe "Shipments" do
  
  Spree::Zone.delete_all
  let(:shipping_method) { Factory(:shipping_method, :zone => Factory(:zone, :name => 'North America')) }
  let(:order) { Factory(:completed_order_with_totals, :number => "R100", :state => "complete",  :shipping_method => shipping_method) }

  before(:each) do
    reset_spree_preferences do |config|
      config.allow_backorders = true
    end
    
    order.inventory_units.each do |iu|
      iu.update_attribute_without_callbacks('state', 'sold')
    end
  end

  it "should be able to create a new shipment for an order" do
    visit spree.admin_path
    click_link "Orders"
    within('table#listing_orders tbody tr:nth-child(1)') { click_link "R100" }
    click_link "Shipments"
    
    click_on "New Shipment"
    check "inventory_units_1"
    click_button "Create"
    page.should have_content("successfully created!")
  end

end