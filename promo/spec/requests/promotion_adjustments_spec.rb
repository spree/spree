require 'spec_helper'

describe "Promotion Adjustments" do
  context "coupon promotions" do
    before(:each) do
      fixtures_dir = File.expand_path('../../../../core/db/default', __FILE__)
      ActiveRecord::Fixtures.create_fixtures(fixtures_dir, ['countries', 'zones', 'zone_members', 'states', 'roles'])
      @configuration ||= AppConfiguration.find_or_create_by_name("Default configuration")
      Factory(:shipping_method, :zone => Zone.find_by_name('North America'))
      user = Factory(:admin_user)

      visit admin_path

      fill_in "user_email", :with => user.email
      fill_in "user_password", :with => user.password
      click_button "Log In"
    end

    it "should allow an admin to create a flat rate discount coupon promo", :js => true do
      Factory(:product, :name => "RoR Mug", :price => "40")
      click_link "Promotions"
      click_link "New Promotion"
      fill_in "Name", :with => "Order's total > $30"
      fill_in "Usage Limit", :with => "100"
      select "Coupon code added", :with => "Event"
      fill_in "Code", :with => "ORDER_38"
      click_button "Create"
      page.should have_content("Editing Promotion")

      select "Item total", :from => "Add rule of type"
      within('#rule_fields') { click_button "Add" }
      fill_in "Order total meets these criteria", :with => "30"
      within('#rule_fields') { click_button "Update" }

      select "Create adjustment", :from => "Add action of type"
      within('#action_fields') { click_button "Add" }
      select "Flat Rate (per order)", :from => "Calculator"
      within('#actions_container') { click_button "Update" }
      within('.calculator-fields') { fill_in "Amount", :with => "5" }
      within('#actions_container') { click_button "Update" }

      visit root_path
      click_link "RoR Mug"
      click_button "Add To Cart"
      click_link "Checkout"

      str_addr = "bill_address"
      address = Factory(:address, :state => State.first)
      within('fieldset#billing') { select "United States", :from => "Country" }
      ['firstname', 'lastname', 'address1', 'city', 'zipcode', 'phone'].each do |field|
        fill_in "order_#{str_addr}_attributes_#{field}", :with => "#{address.send(field)}"
      end
      select "#{address.state.name}", :from => "order_#{str_addr}_attributes_state_id"
      check "order_use_billing"
      click_button "Save and Continue"
      click_button "Save and Continue"
      fill_in "order_coupon_code", :with => "ORDER_38"
      click_button "Save and Continue"
      Order.first.total.to_f.should == 47.00
    end
  end
end
