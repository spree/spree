require 'spec_helper'

describe "Checkout" do
  stub_authorization!

  context "visitor makes checkout as guest without registration", :js => true do
    before do
      @product = create(:product, :name => "RoR Mug")
      create(:zone)
      create(:shipping_method)
      create(:payment_method)

      @promotion = create_per_order_coupon_promotion 1, 2, 'onetwo'

      visit spree.root_path
      click_link "RoR Mug"
      click_button "add-to-cart-button"
    end

    # let!(:promotion) { create(:promotion, :code => "onetwo") }
    let(:promotion) { @promotion }

    context "on the payment page" do
      before do
        click_button "Checkout"
        fill_in "order_email", :with => "spree@example.com"
        click_button "Continue"

        fill_in "First Name", :with => "John"
        fill_in "Last Name", :with => "Smith"
        fill_in "Street Address", :with => "1 John Street"
        fill_in "City", :with => "City of John"
        fill_in "Zip", :with => "01337"
        select "United States", :from => "Country"
        select "Alaska", :from => "order[bill_address_attributes][state_id]"
        fill_in "Phone", :with => "555-555-5555"
        check "Use Billing Address"

        # To shipping method screen
        click_button "Save and Continue"
        # To payment screen
        click_button "Save and Continue"
      end

      it "informs about an invalid coupon code" do
        fill_in "Coupon code", :with => "coupon_codes_rule_man"
        click_button "Save and Continue"
        page.should have_content(I18n.t(:coupon_code_not_found))
      end

      it "applies a promotion to an order" do
        fill_in "Coupon code", :with => "onetwo"
        click_button "Save and Continue"
        page.should have_content(I18n.t(:coupon_code_applied))
      end
    end

    # CheckoutController
    context "on the cart page" do
      it "can enter a coupon code and receives success notification" do
        fill_in "Coupon code", :with => "onetwo"
        click_button "Apply"
        page.should have_content(I18n.t(:coupon_code_applied))
      end

      it "can enter a promotion code with both upper and lower case letters" do
        fill_in "Coupon code", :with => "ONETwO"
        click_button "Apply"
        page.should have_content(I18n.t(:coupon_code_applied))
      end

      it "cannot enter a promotion code that was created after the order" do
        promotion.update_column(:created_at, 1.day.from_now)
        fill_in "Coupon code", :with => "onetwo"
        click_button "Apply"
        page.should have_content(I18n.t(:coupon_code_not_found))
      end

      it "informs the user about a coupon code which has exceeded its usage" do
        promotion.update_column(:usage_limit, 5)
        promotion.class.any_instance.stub(:credits_count => 10)

        fill_in "Coupon code", :with => "onetwo"
        click_button "Apply"
        page.should have_content(I18n.t(:coupon_code_max_usage))
      end

      it "informs the user if the previous promotion is better" do
        big_promotion = create_per_order_coupon_promotion 1, 5, 'onefive'
        big_promotion.update_column(:created_at, 1.day.ago)

        visit spree.cart_path

        fill_in "Coupon code", :with => "onefive"
        click_button "Apply"
        page.should have_content(I18n.t(:coupon_code_applied))

        fill_in "Coupon code", :with => "onetwo"
        click_button "Apply"
        page.should have_content(I18n.t(:coupon_code_better_exists))
      end

      it "informs the user if the coupon code is not eligible" do
        promotion.rules.first.preferred_amount = 100

        fill_in "Coupon code", :with => "onetwo"
        click_button "Apply"
        page.should have_content(I18n.t(:coupon_code_not_eligible))
      end

      it "informs the user if the coupon is expired" do
        promotion.expires_at = Date.today.beginning_of_week
        promotion.starts_at = Date.today.beginning_of_week.advance(:day => 3)
        promotion.save!

        fill_in "Coupon code", :with => "onetwo"
        click_button "Apply"
        page.should have_content(I18n.t(:coupon_code_expired))
      end
    end
  end
end
