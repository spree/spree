require 'spec_helper'

describe "Free shipping promotions", :js => true do
  let!(:country) { create(:country, :name => "United States of America", :states_required => true) }
  let!(:state) { create(:state, :name => "Alabama", :country => country) }
  let!(:zone) { create(:zone) }
  let!(:shipping_method) { create(:shipping_method) }
  let!(:payment_method) { create(:check_payment_method) }
  let!(:product) { create(:product, :name => "RoR Mug", :price => 20) }
  let!(:promotion) do
    promotion = Spree::Promotion.create!(:name       => "Free Shipping",
                                         :starts_at  => 1.day.ago,
                                         :expires_at => 1.day.from_now)

    action = Spree::Promotion::Actions::FreeShipping.new
    action.promotion = promotion
    action.save

    promotion.reload # so that promotion.actions is available
  end

  context "free shipping promotion automatically applied" do
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

    it "informs about an invalid coupon code" do
      within("#checkout-summary") do
        page.should have_content("Free Shipping")
      end
    end
  end
end