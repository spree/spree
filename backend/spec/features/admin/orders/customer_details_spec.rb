require 'spec_helper'

describe "Customer Details" do
  stub_authorization!

  let(:shipping_method) { create(:shipping_method, :display_on => "front_end") }
  let(:order) { create(:completed_order_with_totals) }
  let(:country) { create(:country, :name => "Kangaland") }
  let(:state) { create(:state, :name => "Alabama", :country => country) }
  let!(:shipping_method) { create(:shipping_method, :display_on => "front_end") }
  let!(:order) { create(:order, :state => 'complete', :completed_at => "2011-02-01 12:36:15") }

  # We need a unique name that will appear for the customer dropdown
  let!(:ship_address) { create(:address, :country => country, :state => state, :first_name => "Rumpelstiltskin") }
  let!(:bill_address) { create(:address, :country => country, :state => state, :first_name => "Rumpelstiltskin") }

  let!(:user) { create(:user, :email => 'foobar@example.com', :ship_address => ship_address, :bill_address => bill_address) }

  before do
    configure_spree_preferences do |config|
      config.default_country_id = country.id
      config.company = true
    end

    visit spree.admin_path
    click_link "Orders"
    within('table#listing_orders') { click_icon(:edit) }
  end

  # Regression test for #3335
  context "brand new order", :js => true do
    it "associates a user when not using guest checkout" do
      click_link "Orders"
      click_link "New Order"
      click_link "Customer Details" 
      targetted_select2 "foobar@example.com", :from => "#s2id_customer_search"
      fill_in_address
      check "order_use_billing"
      click_button "Update"
      Spree::Order.last.user.should_not be_nil
    end
  end

  context "editing an order", :js => true do
    context "selected country has no state" do
      before { create(:country, iso: "BRA", name: "Brazil") }

      it "changes state field to text input" do
        click_link "Customer Details"

        within("#billing") do
          targetted_select2 "Brazil", :from => "#s2id_order_bill_address_attributes_country_id"
          fill_in "order_bill_address_attributes_state_name", with: "Piaui"
        end

        click_button "Update"
        find_field("order_bill_address_attributes_state_name").value.should == "Piaui"
      end
    end

    it "should be able to update customer details for an existing order" do
      order.ship_address = create(:address)
      order.save!

      click_link "Customer Details"
      within("#shipping") { fill_in_address "ship" }
      within("#billing") { fill_in_address "bill" }

      click_button "Update"
      click_link "Customer Details"

      # Regression test for #2950 + #2433
      # This act should transition the state of the order as far as it will go too
      within("#order_tab_summary") do
        find(".state").text.should == "COMPLETE"
      end
    end
  end

  it "should show validation errors" do
    click_link "Customer Details"
    click_button "Update"
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

      page.select('Alabama', :from => 'order_ship_address_attributes_state_id')
      fill_in "order_ship_address_attributes_phone",     :with => "123-456-7890"
      lambda { click_button "Update" }.should_not raise_error
    end
  end

  def fill_in_address(kind = "bill")
    fill_in "First Name",              :with => "John 99"
    fill_in "Last Name",               :with => "Doe"
    fill_in "Company",                 :with => "Company"
    fill_in "Street Address",          :with => "100 first lane"
    fill_in "Street Address (cont'd)", :with => "#101"
    fill_in "City",                    :with => "Bethesda"
    fill_in "Zip",                     :with => "20170"
    targetted_select2 "Alabama",       :from => "#s2id_order_#{kind}_address_attributes_state_id"
    fill_in "Phone",                   :with => "123-456-7890"
  end
end
