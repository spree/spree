require 'spec_helper'

describe "Handling on shipping from certain stock locations", :js => true do
  let!(:country) { create(:country, :states_required => true) }
  let!(:state) { create(:state, :country => country) }
  let!(:shipping_method) { create(:shipping_method) }
  let!(:stock_location) { create(:stock_location_with_handling_fee) }
  let!(:mug) { create(:product, :name => "RoR Mug") }
  let!(:payment_method) { create(:check_payment_method) }
  let!(:zone) { create(:zone) }

  context "handling applied in checkout" do
    before do

      visit spree.root_path
      click_link "RoR Mug"
      click_button "add-to-cart-button"
      click_button "Checkout"
      fill_in "order_email", :with => "spree@example.com"
      fill_in "First Name", :with => "John"
      fill_in "Last Name", :with => "Smith"
      fill_in "Street Address", :with => "1 John Street"
      fill_in "City", :with => "City of John"
      fill_in "Zip", :with => "01337"
      select country.name, :from => "Country"
      select state.name, :from => "order[bill_address_attributes][state_id]"
      fill_in "Phone", :with => "555-555-5555"

      # To shipping method screen
      click_button "Save and Continue"
      # To payment screen
      click_button "Save and Continue"
    end

    it "displays the handling fee" do
      within("#checkout-summary") do
        page.should have_content("Item Total:  $10.00")
        page.should have_content("Shipping:  $10.00")
        page.should have_content("Handling:  $10.00")
        page.should have_content("Order Total: $30.00")
      end
    end
  end
end