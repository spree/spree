require 'spec_helper'

describe "Customer Details" do
  stub_authorization!

  let(:shipping_method) { create(:shipping_method, :display_on => "front_end") }
  let(:order) { create(:order_with_inventory_unit_shipped, :completed_at => 1.year.ago, :shipping_method => shipping_method) }
  let(:country) do
    create(:country, :name => "Kangaland")
  end

  let(:state) do
    create(:state, :name => "Alabama", :country => country)
  end

  before do
    reset_spree_preferences do |config|
      config.default_country_id = country.id
      config.company = true
    end

    create(:shipping_method, :display_on => "front_end")
    create(:order_with_inventory_unit_shipped, :completed_at => "2011-02-01 12:36:15")
    ship_address = create(:address, :country => country, :state => state)
    bill_address = create(:address, :country => country, :state => state)
    create(:user, :email => 'foobar@example.com',
                  :ship_address => ship_address,
                  :bill_address => bill_address)

    visit spree.admin_path
    click_link "Orders"
    within('table#listing_orders') { click_icon(:edit) }
  end

  context "editing an order", :js => true do
    it "should be able to populate customer details for an existing order" do
      click_link "Customer Details"
      fill_in "customer_search", :with => "foobar"
      sleep(3)
      page.execute_script %Q{ $('.ui-menu-item a:contains("foobar@example.com")').trigger("mouseenter").click(); }

      ["ship_address", "bill_address"].each do |address|
        find_field("order_#{address}_attributes_firstname").value.should == "John"
        find_field("order_#{address}_attributes_lastname").value.should == "Doe"
        find_field("order_#{address}_attributes_company").value.should == "Company"
        find_field("order_#{address}_attributes_address1").value.should == "10 Lovely Street"
        find_field("order_#{address}_attributes_address2").value.should == "Northwest"
        find_field("order_#{address}_attributes_city").value.should == "Herndon"
        find_field("order_#{address}_attributes_zipcode").value.should == "20170"
        find_field("order_#{address}_attributes_state_id").value.should == state.id.to_s
        find_field("order_#{address}_attributes_country_id").value.should == country.id.to_s
        find_field("order_#{address}_attributes_phone").value.should == "123-456-7890"
      end
    end

    it "should be able to update customer details for an existing order" do
      order.ship_address = create(:address)
      order.save!

      click_link "Customer Details"
      ["ship", "bill"].each do |type|
        fill_in "order_#{type}_address_attributes_firstname",  :with => "John 99"
        fill_in "order_#{type}_address_attributes_lastname",   :with => "Doe"
        fill_in "order_#{type}_address_attributes_lastname",   :with => "Company"
        fill_in "order_#{type}_address_attributes_address1",   :with => "100 first lane"
        fill_in "order_#{type}_address_attributes_address2",   :with => "#101"
        fill_in "order_#{type}_address_attributes_city",       :with => "Bethesda"
        fill_in "order_#{type}_address_attributes_zipcode",    :with => "20170"
        select "Alabama", :from => "order_#{type}_address_attributes_state_id"
        fill_in "order_#{type}_address_attributes_phone",     :with => "123-456-7890"
      end

      click_button "Continue"

      click_link "Customer Details"
      find_field('order_ship_address_attributes_firstname').value.should == "John 99"
    end
  end

  it "should show validation errors" do
    click_link "Customer Details"
    click_button "Continue"
    page.should have_content("Shipping address first name can't be blank")
  end


  # Regression test for #942
  context "errors when no shipping methods are available" do
    before do
      Spree::ShippingMethod.delete_all
    end

    specify do
      click_link "Customer Details"
      # Need to fill in valid information so it passes validations
      fill_in "order_ship_address_attributes_firstname",  :with => "John 99"
      fill_in "order_ship_address_attributes_lastname",   :with => "Doe"
      fill_in "order_ship_address_attributes_lastname",   :with => "Company"
      fill_in "order_ship_address_attributes_address1",   :with => "100 first lane"
      fill_in "order_ship_address_attributes_address2",   :with => "#101"
      fill_in "order_ship_address_attributes_city",       :with => "Bethesda"
      fill_in "order_ship_address_attributes_zipcode",    :with => "20170"
      fill_in "order_ship_address_attributes_state_name", :with => "Alabama"
      fill_in "order_ship_address_attributes_phone",     :with => "123-456-7890"
      lambda { click_button "Continue" }.should_not raise_error(NoMethodError)
    end


  end

end
