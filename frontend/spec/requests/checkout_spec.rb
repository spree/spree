require 'spec_helper'

describe "Checkout" do
  let!(:country) { create(:country, :name => "Kangaland",:states_required => true) }
  let!(:state) { create(:state, :name => "Victoria", :country => country) }

  context "visitor makes checkout as guest without registration" do
    before(:each) do
      Spree::Product.delete_all
      @product = create(:product, :name => "RoR Mug")
      @product.on_hand = 1
      @product.save
      create(:zone)
      create(:shipping_method)
      create(:payment_method)
    end

    context "when backordering is disabled" do
      before(:each) do
        reset_spree_preferences do |config|
          config.allow_backorders = false
        end
      end

      it "should warn the user about out of stock items" do
        visit spree.root_path
        click_link "RoR Mug"
        click_button "add-to-cart-button"

        @product.on_hand = 0
        @product.save

        click_button "Checkout"

        within(:css, "span.out-of-stock") { page.should have_content("Out of Stock") }
      end
    end

    context "defaults to use billing address" do
      before do
        shipping_method = create(:shipping_method)
        shipping_method.zone.zone_members << Spree::ZoneMember.create(:zoneable => country)

        @order = OrderWalkthrough.up_to(:address)
        @order.stub(:available_payment_methods => [ create(:bogus_payment_method, :environment => 'test') ])

        visit spree.root_path
        click_link "RoR Mug"
        click_button "add-to-cart-button"
        Spree::Order.last.update_column(:email, "ryan@spreecommerce.com")
        click_button "Checkout"
      end

      it "should default checkbox to checked" do
        find('input#order_use_billing').should be_checked
      end

      it "should remain checked when used and visitor steps back to address step", :js => true do
        address = "order_bill_address_attributes"
        fill_in "#{address}_firstname", :with => "Ryan"
        fill_in "#{address}_lastname", :with => "Bigg"
        fill_in "#{address}_address1", :with => "143 Swan Street"
        fill_in "#{address}_city", :with => "Richmond"
        select "Kangaland", :from => "#{address}_country_id"
        select "Victoria", :from => "#{address}_state_id"
        fill_in "#{address}_zipcode", :with => "12345"
        fill_in "#{address}_phone", :with => "(555) 5555-555"
        click_button "Save and Continue"
        click_link "Address"

        find('input#order_use_billing').should be_checked
      end
    end

    context "and likes to double click buttons" do
      before(:each) do
        order = OrderWalkthrough.up_to(:delivery)
        order.stub :confirmation_required? => true

        order.reload
        order.update!

        Spree::CheckoutController.any_instance.stub(:current_order => order)
        Spree::CheckoutController.any_instance.stub(:skip_state_validation? => true)
      end

      it "prevents double clicking the payment button on checkout", :js => true do
        visit spree.checkout_state_path(:payment)

        # prevent form submit to verify button is disabled
        page.execute_script("$('#checkout_form_payment').submit(function(){return false;})")

        page.should_not have_selector('input.button[disabled]')
        click_button "Save and Continue"
        page.should have_selector('input.button[disabled]')
      end

      it "prevents double clicking the confirm button on checkout", :js => true do
        visit spree.checkout_state_path(:confirm)

        # prevent form submit to verify button is disabled
        page.execute_script("$('#checkout_form_confirm').submit(function(){return false;})")

        page.should_not have_selector('input.button[disabled]')
        click_button "Place Order"
        page.should have_selector('input.button[disabled]')
      end

      # Regression test for #1596
      context "full checkout" do
        before do
          create(:payment_method)
          Spree::ShippingMethod.delete_all
          shipping_method = create(:shipping_method)
          calculator = Spree::Calculator::PerItem.create!({:calculable => shipping_method}, :without_protection => true)
          shipping_method.calculator = calculator
          shipping_method.save

          @product.shipping_category = shipping_method.shipping_category
          @product.save!
        end

        it "does not break the per-item shipping method calculator", :js => true do
          visit spree.root_path
          click_link "RoR Mug"
          click_button "add-to-cart-button"
          click_button "Checkout"
          Spree::Order.last.update_column(:email, "ryan@spreecommerce.com")

          address = "order_bill_address_attributes"
          fill_in "#{address}_firstname", :with => "Ryan"
          fill_in "#{address}_lastname", :with => "Bigg"
          fill_in "#{address}_address1", :with => "143 Swan Street"
          fill_in "#{address}_city", :with => "Richmond"
          select "Kangaland", :from => "#{address}_country_id"
          select "Victoria", :from => "#{address}_state_id"
          fill_in "#{address}_zipcode", :with => "12345"
          fill_in "#{address}_phone", :with => "(555) 5555-555"

          click_button "Save and Continue"
          page.should_not have_content("undefined method `promotion'")
        end
      end
    end

    context "promotions", :js => true do
      # OrdersController
      context "on the payment page" do
        before do
          visit spree.root_path
          click_link "RoR Mug"
          click_button "add-to-cart-button"
          click_button "Checkout"
          fill_in "order_email", :with => "spree@example.com"
          click_button "Continue"

          fill_in "First Name", :with => "John"
          fill_in "Last Name", :with => "Smith"
          fill_in "Street Address", :with => "1 John Street"
          fill_in "City", :with => "City of John"
          fill_in "Zip", :with => "01337"
          select country.name, :from => "Country"
          select state.name, :from => "order[bill_address_attributes][state_id]"
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

        context "with a promotion" do
          before do
            create_basic_coupon_promotion("onetwo")
          end

          it "applies a promotion to an order" do
            fill_in "Coupon code", :with => "onetwo"
            click_button "Save and Continue"
            page.should have_content(I18n.t(:coupon_code_applied))
          end
        end
      end

      # CheckoutController
      context "on the cart page" do
        let!(:promotion) { create_basic_coupon_promotion("onetwo") }

        before do
          visit spree.root_path
          click_link "RoR Mug"
          click_button "add-to-cart-button"
        end

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

        context "informs the user if the previous promotion is better" do
          before do
            better_promotion = create_basic_coupon_promotion("50off")
            calculator = better_promotion.actions.first.calculator
            calculator.preferred_amount = 50
            calculator.save
          end

          specify do
            visit spree.cart_path

            fill_in "Coupon code", :with => "50off"
            click_button "Apply"
            page.should have_content(I18n.t(:coupon_code_applied))

            fill_in "Coupon code", :with => "onetwo"
            click_button "Apply"
            page.should have_content(I18n.t(:coupon_code_better_exists))
          end
        end

        context "informs the user if the coupon code is not eligible" do
          before do
            rule = Spree::Promotion::Rules::ItemTotal.new
            rule.promotion = promotion
            rule.preferred_amount = 100
            rule.save
          end

          specify do
            visit spree.cart_path

            fill_in "Coupon code", :with => "onetwo"
            click_button "Apply"
            page.should have_content(I18n.t(:coupon_code_not_eligible))
          end
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
end
