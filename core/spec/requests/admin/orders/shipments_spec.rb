require 'spec_helper'

describe "Shipments" do
  
  Spree::Zone.delete_all
  let(:shipping_method) { create(:shipping_method, :zone => Spree::Zone.find_by_name('North America') || create(:zone, :name => 'North America')) }
  let(:order) { create(:completed_order_with_totals, :number => "R100", :state => "complete",  :shipping_method => shipping_method) }

  before(:each) do
    reset_spree_preferences do |config|
      config.allow_backorders = true
    end
    
    order.inventory_units.each do |iu|
      iu.update_attribute_without_callbacks('state', 'sold')
    end
    
    visit spree.admin_path
    click_link "Orders"
    within('table#listing_orders tbody tr:nth-child(1)') { click_link "R100" }
    
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
    find('table.index tr:nth-child(2) td:nth-child(1)').text.should == order.shipment.number
    find('table.index tr:nth-child(2) td:nth-child(5)').text.should == "Pending"
    
    within('table.index tr:nth-child(2) td:nth-child(7)') { click_link "Edit" }
    page.should have_content("Shipment ##{order.shipment.number}")
  end

end
