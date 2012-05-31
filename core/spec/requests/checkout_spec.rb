require 'spec_helper'

describe "Checkout" do
  context "visitor makes checkout as guest without registration" do
    context "when backordering is disabled" do
      before(:each) do
        reset_spree_preferences do |config|
          config.allow_backorders = false
        end
        Spree::Product.delete_all
        @product = create(:product, :name => "RoR Mug")
        @product.on_hand = 1
        @product.save
        create(:zone)
      end

      it "should warn the user about out of stock items" do
        pending "Failing when run in tandem with spec/requests/admin/orders/customer_details_spec.rb. Recommended to fix that one first."
        visit spree.root_path
        click_link "RoR Mug"
        click_button "add-to-cart-button"

        @product.on_hand = 0
        @product.save

        click_link "Checkout"

        within(:css, "span.out-of-stock") { page.should have_content("Out of Stock") }
      end

      # Regression test for #1596
      context "does not break the per-item shipping method calculator", :js => true do
        before do
          Factory(:payment_method)
          Spree::ShippingMethod.delete_all
          shipping_method = Factory(:shipping_method)
          calculator = Spree::Calculator::PerItem.create!({:calculable => shipping_method}, :without_protection => true)
          shipping_method.calculator = calculator
          shipping_method.save

          @product.shipping_category = shipping_method.shipping_category
          @product.save!
        end

        specify do
          visit spree.root_path
          click_link "RoR Mug"
          click_button "add-to-cart-button"
          click_link "Checkout"
          Spree::Order.last.update_attribute(:email, "ryan@spreecommerce.com")

          address = "order_bill_address_attributes"
          fill_in "#{address}_firstname", :with => "Ryan"
          fill_in "#{address}_lastname", :with => "Bigg"
          fill_in "#{address}_address1", :with => "143 Swan Street"
          fill_in "#{address}_city", :with => "Richmond"
          select "United States", :from => "#{address}_country_id"
          select "Alabama", :from => "#{address}_state_id"
          fill_in "#{address}_zipcode", :with => "12345"
          fill_in "#{address}_phone", :with => "(555) 5555-555"

          check "Use Billing Address"
          click_button "Save and Continue"
          page.should_not have_content("undefined method `promotion'")
        end

      end
    end
  end
end
