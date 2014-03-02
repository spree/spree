require 'spec_helper'

describe "Checkout", inaccessible: true do

  let!(:country) { create(:country, :states_required => true) }
  let!(:state) { create(:state, :country => country) }
  let!(:shipping_method) { create(:shipping_method) }
  let!(:stock_location) { create(:stock_location) }
  let!(:mug) { create(:product, :name => "RoR Mug") }
  let!(:payment_method) { create(:check_payment_method) }
  let!(:zone) { create(:zone) }

  context "visitor makes checkout as guest without registration" do
    before(:each) do
      stock_location.stock_items.update_all(count_on_hand: 1)
    end

    context "defaults to use billing address" do
      before do
        add_mug_to_cart
        Spree::Order.last.update_column(:email, "test@example.com")
        click_button "Checkout"
      end

      it "should default checkbox to checked", inaccessible: true do
        find('input#order_use_billing').should be_checked
      end

      it "should remain checked when used and visitor steps back to address step", :js => true do
        fill_in_address
        find('input#order_use_billing').should be_checked
      end
    end

    # Regression test for #4079
    context "persists state when on address page" do
      before do
        add_mug_to_cart
        click_button "Checkout"
      end

      specify do
        Spree::Order.count.should == 1
        Spree::Order.last.state.should == "address"
      end
    end

    # Regression test for #1596
    context "full checkout" do
      before do
        shipping_method.calculator.update!(preferred_amount: 10)
        mug.shipping_category = shipping_method.shipping_categories.first
        mug.save!
      end

      it "does not break the per-item shipping method calculator", :js => true do
        add_mug_to_cart
        click_button "Checkout"

        fill_in "order_email", :with => "test@example.com"
        fill_in_address

        click_button "Save and Continue"
        page.should_not have_content("undefined method `promotion'")
        click_button "Save and Continue"
        page.should have_content("Shipping total $10.00")
      end
    end
  end

  # Regression test for #2694 and #4117
  context "doesn't allow bad credit card numbers" do
    before(:each) do
      order = OrderWalkthrough.up_to(:delivery)
      order.stub :confirmation_required? => true
      order.stub(:available_payment_methods => [ create(:credit_card_payment_method, :environment => 'test') ])

      user = create(:user)
      order.user = user
      order.update!

      Spree::CheckoutController.any_instance.stub(:current_order => order)
      Spree::CheckoutController.any_instance.stub(:try_spree_current_user => user)
    end

    it "redirects to payment page", inaccessible: true do
      visit spree.checkout_state_path(:delivery)
      click_button "Save and Continue"
      choose "Credit Card"
      fill_in "Card Number", :with => '123'
      fill_in "card_expiry", :with => '04 / 20'
      fill_in "Card Code", :with => '123'
      click_button "Save and Continue"
      click_button "Place Order"
      page.should have_content("Bogus Gateway: Forced failure")
      page.current_url.should include("/checkout/payment")
    end
  end

  #regression test for #3945
  context "when Spree::Config[:always_include_confirm_step] is true" do
    before do
      Spree::Config[:always_include_confirm_step] = true
    end

    it "displays confirmation step", :js => true do
      add_mug_to_cart
      click_button "Checkout"

      fill_in "order_email", :with => "test@example.com"
      fill_in_address

      click_button "Save and Continue"
      click_button "Save and Continue"
      click_button "Save and Continue"

      continue_button = find(".continue")
      continue_button.value.should == "Place Order"
    end
  end

  context "and likes to double click buttons" do
    let!(:user) { create(:user) }
    
    let!(:order) do
      order = OrderWalkthrough.up_to(:delivery)
      order.stub :confirmation_required? => true

      order.reload
      order.user = user
      order.update!
      order
    end

    before(:each) do
      Spree::CheckoutController.any_instance.stub(:current_order => order)
      Spree::CheckoutController.any_instance.stub(:try_spree_current_user => user)
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
      order.payments << create(:payment)
      visit spree.checkout_state_path(:confirm)

      # prevent form submit to verify button is disabled
      page.execute_script("$('#checkout_form_confirm').submit(function(){return false;})")

      page.should_not have_selector('input.button[disabled]')
      click_button "Place Order"
      page.should have_selector('input.button[disabled]')
    end
  end

  context "when several payment methods are available" do
    let(:credit_cart_payment) {create(:credit_card_payment_method, :environment => 'test') }
    let(:check_payment) {create(:check_payment_method, :environment => 'test') }

    after do
      Capybara.ignore_hidden_elements = true
    end

    before do
      Capybara.ignore_hidden_elements = false
      order = OrderWalkthrough.up_to(:delivery)
      order.stub(:available_payment_methods => [check_payment,credit_cart_payment])
      order.user = create(:user)
      order.update!

      Spree::CheckoutController.any_instance.stub(current_order: order)
      Spree::CheckoutController.any_instance.stub(try_spree_current_user: order.user)

      visit spree.checkout_state_path(:payment)
    end

    it "the first payment method should be selected", :js => true do
      payment_method_css = "#order_payments_attributes__payment_method_id_"
      find("#{payment_method_css}#{check_payment.id}").should be_checked
      find("#{payment_method_css}#{credit_cart_payment.id}").should_not be_checked
    end

    it "the fields for the other payment methods should be hidden", :js => true do
      payment_method_css = "#payment_method_"
      find("#{payment_method_css}#{check_payment.id}").should be_visible
      find("#{payment_method_css}#{credit_cart_payment.id}").should_not be_visible
    end
  end

  # regression for #2921
  context "goes back from payment to add another item", js: true do
    let!(:bag) { create(:product, :name => "RoR Bag") }

    it "transit nicely through checkout steps again" do
      add_mug_to_cart
      click_on "Checkout"
      fill_in "order_email", :with => "test@example.com"
      fill_in_address
      click_on "Save and Continue"
      click_on "Save and Continue"
      expect(current_path).to eql(spree.checkout_state_path("payment"))

      visit spree.root_path
      click_link bag.name
      click_button "add-to-cart-button"

      click_on "Checkout"
      click_on "Save and Continue"
      click_on "Save and Continue"
      click_on "Save and Continue"

      expect(current_path).to eql(spree.order_path(Spree::Order.last))
    end
  end

  context "from payment step customer goes back to cart", js: true do
    before do
      add_mug_to_cart
      click_on "Checkout"
      fill_in "order_email", :with => "test@example.com"
      fill_in_address
      click_on "Save and Continue"
      click_on "Save and Continue"
      expect(current_path).to eql(spree.checkout_state_path("payment"))
    end

    context "and updates line item quantity and try to reach payment page" do
      before do
        visit spree.cart_path
        within ".cart-item-quantity" do
          fill_in first("input")["name"], with: 3
        end

        click_on "Update"
      end

      it "redirects user back to address step" do
        visit spree.checkout_state_path("payment")
        expect(current_path).to eql(spree.checkout_state_path("address"))
      end

      it "updates shipments properly through step address -> delivery transitions" do
        visit spree.checkout_state_path("payment")
        click_on "Save and Continue"
        click_on "Save and Continue"

        expect(Spree::InventoryUnit.count).to eq 3
      end
    end

    context "and adds new product to cart and try to reach payment page" do
      let!(:bag) { create(:product, :name => "RoR Bag") }

      before do
        visit spree.root_path
        click_link bag.name
        click_button "add-to-cart-button"
      end

      it "redirects user back to address step" do
        visit spree.checkout_state_path("payment")
        expect(current_path).to eql(spree.checkout_state_path("address"))
      end

      it "updates shipments properly through step address -> delivery transitions" do
        visit spree.checkout_state_path("payment")
        click_on "Save and Continue"
        click_on "Save and Continue"

        expect(Spree::InventoryUnit.count).to eq 2
      end
    end
  end

  context "in coupon promotion, submits coupon along with payment", js: true do
    let!(:promotion) { Spree::Promotion.create(name: "Huhuhu", code: "huhu") }
    let!(:calculator) { Spree::Calculator::FlatPercentItemTotal.create(preferred_flat_percent: "10") }
    let!(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator) }

    before do
      promotion.actions << action

      add_mug_to_cart
      click_on "Checkout"

      fill_in "order_email", :with => "test@example.com"
      fill_in_address
      click_on "Save and Continue"

      click_on "Save and Continue"
      expect(current_path).to eql(spree.checkout_state_path("payment"))
    end

    it "makes sure payment reflects order total with discounts" do
      fill_in "Coupon Code", with: promotion.code
      click_on "Save and Continue"

      page.should have_content(promotion.name)
      expect(Spree::Payment.first.amount.to_f).to eq Spree::Order.last.total.to_f
    end

    context "invalid coupon" do
      it "doesnt create a payment record" do
        fill_in "Coupon Code", with: 'invalid'
        click_on "Save and Continue"

        expect(Spree::Payment.count).to eq 0
        expect(page).to have_content(Spree.t(:coupon_code_not_found))
      end
    end

    context "doesn't fill in coupon code input" do
      it "advances just fine" do
        click_on "Save and Continue"
        expect(current_path).to eql(spree.order_path(Spree::Order.last))
      end
    end
  end

  context "order has only payment step" do
    before do
      create(:credit_card_payment_method)
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        checkout_flow do
          go_to_state :payment
          go_to_state :confirm
        end
      end

      Spree::Order.any_instance.stub email: "spree@commerce.com"

      add_mug_to_cart
      click_on "Checkout"
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it "goes right payment step and place order just fine" do
      expect(current_path).to eq spree.checkout_state_path('payment')

      choose "Credit Card"
      fill_in "Name on card", :with => 'Spree Commerce'
      fill_in "Card Number", :with => '4111111111111111'
      fill_in "card_expiry", :with => '04 / 20'
      fill_in "Card Code", :with => '123'
      click_button "Save and Continue"

      expect(current_path).to eq spree.checkout_state_path('confirm')
      click_button "Place Order"
    end
  end

  def fill_in_address
    address = "order_bill_address_attributes"
    fill_in "#{address}_firstname", :with => "Ryan"
    fill_in "#{address}_lastname", :with => "Bigg"
    fill_in "#{address}_address1", :with => "143 Swan Street"
    fill_in "#{address}_city", :with => "Richmond"
    select "United States of America", :from => "#{address}_country_id"
    select "Alabama", :from => "#{address}_state_id"
    fill_in "#{address}_zipcode", :with => "12345"
    fill_in "#{address}_phone", :with => "(555) 555-5555"
  end

  def add_mug_to_cart
    visit spree.root_path
    click_link mug.name
    click_button "add-to-cart-button"
  end
end
