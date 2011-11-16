require 'spec_helper'

describe "Customer Details" do
  context "editing an order", :js => true do
    before(:each) do
      @configuration ||= Spree::AppConfiguration.find_or_create_by_name("Default configuration")
      Spree::Config.set :default_country_id => Factory(:country).id


      Factory(:shipping_method, :display_on => "front_end")
      Factory(:order, :completed_at => "2011-02-01 12:36:15", :ship_address => Factory(:address))
      Factory(:order, :completed_at => "2010-02-01 17:36:42", :ship_address => Factory(:address))
      Spree::Order.all.each do |order|
        product = Factory(:product, :name => 'spree t-shirt')
        order.add_variant(product.master, 2)
        Factory(:line_item, :order => order, :quantity => 0)
      end

      visit spree_core.admin_path
    end

    it "should be able to update customer details for an existing order" do
      pending
      click_link "Orders"
      within(:css, 'table#listing_orders tr:nth-child(2)') { click_link "Edit" }
      click_link "Customer Details"

      fill_in "order_ship_address_attributes_firstname", :with => "John 99"
      fill_in "order_ship_address_attributes_lastname",  :with => "Doe"
      fill_in "order_ship_address_attributes_address1",  :with => "100 first lane"
      fill_in "order_ship_address_attributes_address2",  :with => "#101"
      fill_in "order_ship_address_attributes_city",      :with => "Bethesda"
      fill_in "order_ship_address_attributes_zipcode",   :with => "20170"
      select Spree::Country.first.states.first.name,     :from => "order_ship_address_attributes_state_id"
      fill_in "order_ship_address_attributes_phone",     :with => "123-456-7890"
      click_button "Continue"

      visit admin_path
      click_link "Orders"
      within(:css, 'table#listing_orders tr:nth-child(2)') { click_link "Edit" }
      click_link "Customer Details"
      find_field('order_ship_address_attributes_firstname').value.should == "John 99"
    end

    it "should show validation errors" do
      pending
      click_link "Orders"
      within(:css, 'table#listing_orders tr:nth-child(2)') { click_link "Edit" }
      click_link "Customer Details"
      click_button "Continue"
      page.should have_content("Shipping address first name can't be blank")
    end
  end
end
