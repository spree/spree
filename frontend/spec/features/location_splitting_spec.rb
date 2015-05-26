require 'spec_helper'

describe 'shipping', type: :feature, js: true do
  let!(:user) { create(:user) }

  let!(:east_coast_location) { create(:east_coast_stock_location, backorderable_default: true) }
  let!(:west_coast_location) { create(:west_coast_stock_location) }

  def fill_in_address(addr_type, address)
    address_field = "#{addr_type}_attributes"
    fill_in "#{address_field}_firstname", with: address.firstname
    fill_in "#{address_field}_lastname", with: address.lastname
    fill_in "#{address_field}_address1", with: address.address1
    fill_in "#{address_field}_address2", with: address.address2
    fill_in "#{address_field}_city", with: address.city
    select "#{address.state.name}", from: "#{address_field}_state_id"
    fill_in "#{address_field}_zipcode", with: address.zipcode
    fill_in "#{address_field}_phone", with: address.phone
  end

  describe 'deciding from which location to ship' do
    include_context 'checkout setup'

    before do
      Spree::StockLocation.last.destroy # get rid of NY

      visit spree.root_path
      click_link mug.name
      fill_in 'quantity', with: 2
      click_button "add-to-cart-button"
      @order = Spree::Order.last
      @order.update_column(:email, "test@example.com")

      puts Spree::StockLocation.all.to_a.map { |s| s.name }

      @east_coast_address = create(:ship_address,
                                   zipcode: '27703',
                                   city: 'Durham',
                                   state: east_coast_location.state,
                                   country: east_coast_location.country)

      @order.update_attributes(ship_address: @east_coast_address)
      click_button 'Checkout'
    end

    it 'ensures that packages ship from both locations since there is one in each' do
      Spree::StockItem.all.each { |si| si.set_count_on_hand(1); si.update_attributes!(backorderable: false) }

      fill_in_address 'order_bill_address', @order.ship_address
      check 'order_use_billing'
      click_button 'Save and Continue'

      page.should have_content 'East Coast'
      page.should have_content 'West Coast'
      page.should_not have_content 'Unshippable Items'
    end
  end
end
