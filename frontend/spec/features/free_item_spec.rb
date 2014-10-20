require 'spec_helper'

# Gigantic regression test for #2191
describe "Free shipping promotions", :type => :feature, :js => true do
  let!(:country) { create(:country, :name => "United States of America", :states_required => true) }
  let!(:state) { create(:state, :name => "Alabama", :country => country) }
  let!(:zone) { create(:zone) }
  let!(:shipping_method) do
    sm = create(:shipping_method)
    sm.calculator.preferred_amount = 10
    sm.calculator.save
    sm
  end

  let!(:payment_method) { create(:check_payment_method) }
  let!(:product) { create(:product, :name => "RoR Mug", :price => 20) }
  let!(:free_product) { create(:product, :name => "RoR Shirt", :price => 20) }
  let!(:promotion) do
    promotion = Spree::Promotion.create!(:name       => "Free Shirt!",
                                         :starts_at  => 1.day.ago,
                                         :expires_at => 1.day.from_now,
                                         :code       => "freeshirt")

    action_1 = Spree::Promotion::Actions::CreateLineItems.new
    action_1.promotion_action_line_items.build(
      :variant => free_product.master,
      :quantity => 1
    )
    action_1.promotion = promotion
    action_1.save

    action_2 = Spree::Promotion::Actions::CreateAdjustment.new
    action_2.calculator = Spree::Calculator::FlatRate.new
    action_2.calculator.preferred_amount = 20
    action_2.promotion = promotion

    action_2.save

    promotion.reload # so that promotion.actions is available
  end

  context "promotion with free line item" do
    before do

      visit spree.root_path
      click_link "RoR Mug"
      click_button "add-to-cart-button"
      fill_in "order_coupon_code", :with => "freeshirt"
      click_button "Update"

      all("a.delete").first.click # Delete the first line item
      expect(page).not_to have_content("RoR Mug")
      expect(page).to have_content("RoR Shirt")
      expect(page).to have_content("Adjustment: Promotion (Free Shirt!) -$20.00")
      expect(page).to have_content("Total $0.00")

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

    # The actual regression test for #2191
    it "does not skip the payment step" do
      # The bug is that it skips the payment step because the shipment cost has not been set for the order.
      # Therefore we are checking here that it's *definitely* on the payment step and hasn't jumped to complete.
      expect(page.current_url).to match(/checkout\/payment/)

      within("#checkout-summary") do
        expect(page).to have_content("Shipping total:  $10.00")
        expect(page).to have_content("Promotion (Free Shirt!): -$20.00")
        expect(page).to have_content("Order Total: $10.00")
      end
    end
  end
end
