require 'spec_helper'

describe "Customer Details" do
  before(:each) do
    @configuration ||= Spree::AppConfiguration.find_or_create_by_name("Default configuration")
    Spree::Config.set :default_country_id => Factory(:country).id

    Factory(:shipping_method, :display_on => "front_end")
    Factory(:order, :completed_at => "2011-02-01 12:36:15", :ship_address => Factory(:address))
    Factory(:order, :completed_at => "2010-02-01 17:36:42", :ship_address => Factory(:address))
    Factory(:user, :email => 'foobar@example.com', :ship_address => Factory(:address), :bill_address => Factory(:address))

    Spree::Order.all.each do |order|
      product = Factory(:product, :name => 'spree t-shirt')
      order.add_variant(product.master, 2)
      Factory(:line_item, :order => order, :quantity => 0)
    end

    sign_in_as!(Factory(:admin_user))
    visit spree.admin_path
    click_link "Orders"
    within(:css, 'table#listing_orders tr:nth-child(2)') { click_link "Edit" }
    click_link "Customer Details"
  end

  context "editing an order", :js => true do
    it "should be able to populate customer details for an existing order" do
      fill_in "customer_search", :with => "foobar"
      sleep(3)

      page.execute_script %Q{ $('.ui-menu-item a:contains("foobar@example.com")').trigger("mouseenter").click(); }

      ["ship_address", "bill_address"].each do |address|
        find_field("order_#{address}_attributes_firstname").value.should == "John"
        find_field("order_#{address}_attributes_lastname").value.should == "Doe"
        find_field("order_#{address}_attributes_address1").value.should == "10 Lovely Street"
        find_field("order_#{address}_attributes_address2").value.should == "Northwest"
        find_field("order_#{address}_attributes_city").value.should == "Herndon"
        find_field("order_#{address}_attributes_zipcode").value.should == "20170"
        find_field("order_#{address}_attributes_state_id").find('option[selected]').text.should == "Alabama"
        find_field("order_#{address}_attributes_country_id").find('option[selected]').text.should == "United States"
        find_field("order_#{address}_attributes_phone").value.should == "123-456-7890"
      end
    end

    it "should be able to update customer details for an existing order" do
      fill_in "order_ship_address_attributes_firstname", :with => "John 99"
      fill_in "order_ship_address_attributes_lastname",  :with => "Doe"
      fill_in "order_ship_address_attributes_address1",  :with => "100 first lane"
      fill_in "order_ship_address_attributes_address2",  :with => "#101"
      fill_in "order_ship_address_attributes_city",      :with => "Bethesda"
      fill_in "order_ship_address_attributes_zipcode",   :with => "20170"
      select "Alabama", :from => "order_ship_address_attributes_state_id"
      fill_in "order_ship_address_attributes_phone",     :with => "123-456-7890"
      click_button "Continue"

      visit spree.admin_path
      click_link "Orders"
      within(:css, 'table#listing_orders tr:nth-child(2)') { click_link "Edit" }

      click_link "Customer Details"
      find_field('order_ship_address_attributes_firstname').value.should == "John 99"
    end

    it "should show validation errors" do
      pending
      click_button "Continue"
      page.should have_content("Shipping address first name can't be blank")
    end
  end
end
