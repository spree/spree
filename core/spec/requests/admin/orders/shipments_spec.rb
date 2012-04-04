require 'spec_helper'

describe "Shipments" do
  
  Spree::Zone.delete_all
  let(:shipping_method) { Factory(:shipping_method, :zone => Spree::Zone.find_by_name('North America') || Factory(:zone, :name => 'North America')) }
  let(:order) { Factory(:completed_order_with_totals, :number => "R100", :state => "complete",  :shipping_method => shipping_method) }

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
    find('table.index tbody tr:nth-child(2) td:nth-child(1)').text.should == order.shipment.number
    find('table.index tbody tr:nth-child(2) td:nth-child(5)').text.should == "Pending"
    
    within('table.index tbody tr:nth-child(2) td:nth-child(7)') { click_link "Edit" }
    page.should have_content("Shipment ##{order.shipment.number}")
    #save_and_open_page
    #click_button "Update"
    #page.should have_content("successfully updated!")
    
  end

end
