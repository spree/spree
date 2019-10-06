require 'spec_helper'

describe 'Checkout', type: :feature, inaccessible: true, js: true do
  include_context 'checkout setup'

  let(:country) { create(:country, name: 'United States of America', iso_name: 'UNITED STATES') }
  let(:state) { create(:state, name: 'Alabama', abbr: 'AL', country: country) }

  context 'visitor makes checkout as guest without registration' do
    before do
      stock_location.stock_items.update_all(count_on_hand: 1)
    end

    context 'defaults to use billing address' do
      before do
        add_mug_to_cart
        Spree::Order.last.update_column(:email, 'test@example.com')
        click_button 'Checkout'
      end

      it 'defaults checkbox to checked' do
        expect(page).to have_checked_field(id: 'order_use_billing')
      end

      it 'remains checked when used and visitor steps back to address step' do
        fill_in_address
        expect(page).to have_checked_field(id: 'order_use_billing')
      end
    end

    # Regression test for #4079
    context 'persists state when on address page' do
      before do
        add_mug_to_cart
        click_button 'Checkout'
      end

      specify do
        expect(Spree::Order.count).to eq 1
        expect(Spree::Order.last.state).to eq 'address'
      end
    end

    # Regression test for #1596
    context 'full checkout' do
      before do
        shipping_method.calculator.update!(preferred_amount: 10)
        mug.shipping_category = shipping_method.shipping_categories.first
        mug.save!
      end

      it 'does not break the per-item shipping method calculator', js: true do
        add_mug_to_cart
        click_button 'Checkout'

        fill_in 'order_email', with: 'test@example.com'
        click_on 'Continue'
        fill_in_address

        click_button 'Save and Continue'
        expect(page).not_to have_content("undefined method `promotion'")
        click_button 'Save and Continue'
        expect(page).to have_content('Shipping total: $10.00')
      end
    end

    # Regression test for #4306
    context 'free shipping' do
      before do
        add_mug_to_cart
        click_button 'Checkout'
        fill_in 'order_email', with: 'test@example.com'
        click_on 'Continue'
      end

      it "does not show 'Free Shipping' when there are no shipments" do
        within('#checkout-summary') do
          expect(page).not_to have_content('Free Shipping')
        end
      end
    end

    # Regression test for #4190
    it 'updates state_lock_version on form submission', js: true do
      add_mug_to_cart
      click_button 'Checkout'

      expect(page).to have_field(id: 'order_state_lock_version', type: :hidden, with: '0')

      fill_in 'order_email', with: 'test@example.com'
      fill_in_address
      click_button 'Save and Continue'

      expect(page).to have_field(id: 'order_state_lock_version', type: :hidden, with: '1')
    end
  end

  # Regression test for #2694 and #4117
  context "doesn't allow bad credit card numbers" do
    before do
      order = OrderWalkthrough.up_to(:payment)
      allow(order).to receive_messages confirmation_required?: true
      allow(order).to receive_messages(available_payment_methods: [create(:credit_card_payment_method)])

      user = create(:user)
      order.user = user
      order.update_with_updater!

      allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: user)
    end

    it 'redirects to payment page', inaccessible: true, js: true do
      visit spree.checkout_state_path(:payment)
      click_button 'Save and Continue'
      choose 'Credit Card'
      fill_in 'Card Number', with: '123'
      fill_in 'card_expiry', with: '04 / 20'
      fill_in 'Card Code', with: '123'
      click_button 'Save and Continue'
      click_button 'Place Order'
      expect(page).to have_content('Bogus Gateway: Forced failure')
      expect(page).to have_current_path(%r{/checkout/payment})
    end
  end

  # regression test for #3945
  context 'when Spree::Config[:always_include_confirm_step] is true' do
    before do
      Spree::Config[:always_include_confirm_step] = true
    end

    it 'displays confirmation step', js: true do
      add_mug_to_cart
      click_button 'Checkout'

      fill_in 'order_email', with: 'test@example.com'
      click_on 'Continue'
      fill_in_address

      click_button 'Save and Continue'
      click_button 'Save and Continue'
      click_button 'Save and Continue'

      expect(find('#checkout')).to have_button(class: 'btn-success', value: 'Place Order')
    end
  end

  context 'and likes to double click buttons' do
    let!(:user) { create(:user) }

    let!(:order) do
      order = OrderWalkthrough.up_to(:payment)
      allow(order).to receive_messages confirmation_required?: true

      order.reload
      order.user = user
      order.update_with_updater!
      order
    end

    before do
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: user)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(skip_state_validation?: true)
    end

    it 'prevents double clicking the payment button on checkout', js: true do
      visit spree.checkout_state_path(:payment)

      # prevent form submit to verify button is disabled
      find('#checkout_form_payment').execute_script('$(this).submit(function(){return false;})')

      expect(page).not_to have_selector('input.btn.disabled')
      click_button 'Save and Continue'
      expect(page).to have_selector('input.btn.disabled')
    end

    it 'prevents double clicking the confirm button on checkout', js: true do
      order.payments << create(:payment, amount: order.amount)
      visit spree.checkout_state_path(:confirm)

      # prevent form submit to verify button is disabled
      find('#checkout_form_confirm').execute_script('$(this).submit(function(){return false;})')

      expect(page).not_to have_selector('input.btn.disabled')
      click_button 'Place Order'
      expect(page).to have_selector('input.btn.disabled')
    end
  end

  context 'when several payment methods are available', js: true do
    let!(:current_store) { create(:store, default: true) }
    let(:credit_cart_payment) { create(:credit_card_payment_method) }
    let(:check_payment) { create(:check_payment_method) }
    let(:unsupported_payment) { create(:check_payment_method, store: create(:store)) }

    before do
      order = OrderWalkthrough.up_to(:payment)
      allow(order).to receive_messages(available_payment_methods: [check_payment, credit_cart_payment, unsupported_payment])
      order.user = create(:user)
      order.update_with_updater!

      allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: order.user)

      visit spree.checkout_state_path(:payment)
    end

    it 'the first payment method should be selected' do
      payment_method_id_prefix = 'order_payments_attributes__payment_method_id_'
      expect(page).to have_checked_field(id: "#{payment_method_id_prefix}#{check_payment.id}")
      expect(page).to have_unchecked_field(id: "#{payment_method_id_prefix}#{credit_cart_payment.id}")
    end

    it 'the fields for the other payment methods should be hidden' do
      payment_method_css = '#payment_method_'
      expect(page).to have_css("#{payment_method_css}#{check_payment.id}", visible: true)
      expect(page).to have_css("#{payment_method_css}#{credit_cart_payment.id}", visible: :hidden)
    end

    it 'only returns supported payment method of current store' do
      expect(page).to have_css("#payment_method_#{unsupported_payment.id}", visible: :hidden)
    end
  end

  context 'user has payment sources', js: true do
    let(:bogus) { create(:credit_card_payment_method) }
    let(:user) { create(:user) }

    before do
      create(:credit_card, user_id: user.id, payment_method: bogus, gateway_customer_profile_id: 'BGS-WEFWF')

      order = OrderWalkthrough.up_to(:payment)
      allow(order).to receive_messages(available_payment_methods: [bogus])

      allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: user)
      allow_any_instance_of(Spree::OrdersController).to receive_messages(try_spree_current_user: user)

      visit spree.checkout_state_path(:payment)
    end

    it 'selects first source available and customer moves on' do
      expect(page).to have_checked_field(id: 'use_existing_card_yes')

      expect { click_on 'Save and Continue' }.not_to change { Spree::CreditCard.count }

      click_on 'Place Order'
      expect(page).to have_current_path(spree.order_path(Spree::Order.last))
    end

    it 'allows user to enter a new source' do
      choose 'use_existing_card_no'

      delayed_fill_in 'Name on card', 'Spree Commerce'
      delayed_fill_in 'Card Number',  '4111111111111111'
      delayed_fill_in 'card_expiry',  '04 / 20'
      delayed_fill_in 'Card Code',    '123'

      expect { click_on 'Save and Continue' }.to change { Spree::CreditCard.count }.by 1

      click_on 'Place Order'

      expect(page).to have_content(Spree.t(:thank_you_for_your_order).gsub(/[[:space:]]+/, ' '))
      expect(page).to have_current_path(spree.order_path(Spree::Order.last))
    end
  end

  # regression for #2921
  context 'goes back from payment to add another item', js: true do
    let!(:bag) { create(:product, name: 'RoR Bag') }

    it 'transit nicely through checkout steps again' do
      add_mug_to_cart
      click_on 'Checkout'
      fill_in 'order_email', with: 'test@example.com'
      click_on 'Continue'
      fill_in_address
      click_on 'Save and Continue'
      click_on 'Save and Continue'
      expect(page).to have_current_path(spree.checkout_state_path('payment'))

      add_to_cart(bag.name)

      click_on 'Checkout'
      click_on 'Save and Continue'
      click_on 'Save and Continue'
      click_on 'Save and Continue'

      expect(page).to have_current_path(spree.order_path(Spree::Order.last))
    end
  end

  context 'from payment step customer goes back to cart', js: true do
    before do
      add_mug_to_cart
      click_on 'Checkout'
      fill_in 'order_email', with: 'test@example.com'
      click_on 'Continue'
      fill_in_address
      click_on 'Save and Continue'
      click_on 'Save and Continue'
      expect(page).to have_current_path(spree.checkout_state_path('payment'))
    end

    context 'and updates line item quantity and try to reach payment page' do
      let(:cart_quantity) { 3 }

      before do
        visit spree.cart_path
        within '.cart-item-quantity' do
          fill_in first('input')['name'], with: cart_quantity
        end

        click_on 'Update'
      end

      it 'redirects user back to address step' do
        visit spree.checkout_state_path('payment')
        expect(page).to have_current_path(spree.checkout_state_path('address'))
      end

      it 'updates shipments properly through step address -> delivery transitions' do
        visit spree.checkout_state_path('payment')
        click_on 'Save and Continue'
        click_on 'Save and Continue'

        expect(Spree::InventoryUnit.count).to eq 1
        expect(Spree::InventoryUnit.first.quantity).to eq cart_quantity
      end
    end

    context 'and adds new product to cart and try to reach payment page' do
      let!(:bag) { create(:product, name: 'RoR Bag') }

      before do
        add_to_cart(bag.name)
      end

      it 'redirects user back to address step' do
        visit spree.checkout_state_path('payment')
        expect(page).to have_current_path(spree.checkout_state_path('address'))
      end

      it 'updates shipments properly through step address -> delivery transitions' do
        visit spree.checkout_state_path('payment')
        click_on 'Save and Continue'
        click_on 'Save and Continue'

        expect(Spree::InventoryUnit.count).to eq 2
      end
    end
  end

  # Regression test for #7734
  context 'if multiple coupon promotions applied' do
    let(:promotion) { Spree::Promotion.create(name: 'Order Promotion', code: 'o_promotion') }
    let(:calculator) { Spree::Calculator::FlatPercentItemTotal.create(preferred_flat_percent: '90') }
    let(:action) { Spree::Promotion::Actions::CreateAdjustment.create(calculator: calculator) }

    let(:promotion_2) { Spree::Promotion.create(name: 'Line Item Promotion', code: 'li_promotion') }
    let(:calculator_2) { Spree::Calculator::FlatRate.create(preferred_amount: '1000') }
    let(:action_2) { Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator_2) }

    before do
      promotion.actions << action
      promotion_2.actions << action_2

      add_mug_to_cart
    end

    it "totals aren't negative" do
      fill_in 'Coupon Code', with: promotion.code
      click_on 'Apply'

      fill_in 'Coupon Code', with: promotion_2.code
      click_on 'Apply'

      expect(page).to have_content(promotion.name)
      expect(page).to have_content(promotion_2.name)
      expect(Spree::Order.last.total.to_f).to eq 0.0
    end
  end

  context 'if coupon promotion, submits coupon along with payment', js: true do
    let!(:promotion) { Spree::Promotion.create(name: 'Huhuhu', code: 'huhu') }
    let!(:calculator) { Spree::Calculator::FlatPercentItemTotal.create(preferred_flat_percent: '10') }
    let!(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator) }

    before do
      promotion.actions << action

      add_mug_to_cart
      click_on 'Checkout'

      fill_in 'order_email', with: 'test@example.com'
      click_on 'Continue'
      fill_in_address
      click_on 'Save and Continue'

      click_on 'Save and Continue'
      expect(page).to have_current_path(spree.checkout_state_path('payment'))
    end

    it 'makes sure payment reflects order total with discounts' do
      fill_in 'Coupon Code', with: promotion.code
      click_on 'Save and Continue'

      expect(page).to have_content(promotion.name)
      expect(Spree::Payment.first.amount.to_f).to eq Spree::Order.last.total.to_f
    end

    context 'invalid coupon' do
      it 'doesnt create a payment record' do
        fill_in 'Coupon Code', with: 'invalid'
        click_on 'Save and Continue'

        expect(Spree::Payment.count).to eq 0
        expect(page).to have_content(Spree.t(:coupon_code_not_found))
      end
    end

    context "doesn't fill in coupon code input" do
      it 'advances just fine' do
        click_on 'Save and Continue'
        expect(page).to have_current_path(spree.order_path(Spree::Order.last))
      end
    end

    context 'the promotion makes order free (downgrade it total to 0.0)' do
      let(:promotion2) { Spree::Promotion.create(name: 'test-7450', code: 'test-7450') }
      let(:calculator2) do
        Spree::Calculator::FlatRate.create(preferences: { currency: 'USD', amount: BigDecimal('99999') })
      end
      let(:action2) { Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator2) }

      before { promotion2.actions << action2 }

      context 'user choose to pay by check' do
        it 'move user to complete checkout step' do
          fill_in 'Coupon Code', with: promotion2.code
          click_on 'Save and Continue'

          expect(page).to have_content(promotion2.name)
          expect(Spree::Order.last.total.to_f).to eq(0)
          expect(page).to have_current_path(spree.order_path(Spree::Order.last))
        end
      end

      context 'user choose to pay by card' do
        let(:bogus) { create(:credit_card_payment_method) }

        before do
          order = Spree::Order.last
          allow(order).to receive_messages(available_payment_methods: [bogus])
          allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)

          visit spree.checkout_state_path(:payment)
        end

        it 'move user to confirmation checkout step' do
          fill_in 'Name on card', with: 'Spree Commerce'
          fill_in 'Card Number', with: '4111111111111111'
          fill_in 'card_expiry', with: '04 / 20'
          fill_in 'Card Code', with: '123'

          fill_in 'Coupon Code', with: promotion2.code
          click_on 'Save and Continue'

          expect(page).to have_content(promotion2.name)
          expect(Spree::Order.last.total.to_f).to eq(0)
          expect(page).to have_current_path(spree.checkout_state_path('confirm'))
        end
      end
    end
  end

  context 'order has only payment step' do
    before do
      create(:credit_card_payment_method)
      @old_checkout_flow = Spree::Order.checkout_flow
      Spree::Order.class_eval do
        checkout_flow do
          go_to_state :payment
          go_to_state :confirm
        end
      end

      allow_any_instance_of(Spree::Order).to receive_messages email: 'spree@commerce.com'

      add_mug_to_cart
      click_on 'Checkout'
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it 'goes right payment step and place order just fine' do
      expect(page).to have_current_path(spree.checkout_state_path('payment'))

      choose 'Credit Card'
      fill_in 'Name on card', with: 'Spree Commerce'
      fill_in 'Card Number', with: '4111111111111111'
      fill_in 'card_expiry', with: '04 / 20'
      fill_in 'Card Code', with: '123'
      click_button 'Save and Continue'

      expect(page).to have_current_path(spree.checkout_state_path('confirm'))
      click_button 'Place Order'
    end
  end

  context 'save my address' do
    before do
      stock_location.stock_items.update_all(count_on_hand: 1)
      add_mug_to_cart
    end

    context 'as a guest' do
      before do
        Spree::Order.last.update_column(:email, 'test@example.com')
        click_button 'Checkout'
      end

      it 'is not displayed' do
        expect(page).not_to have_css('[data-hook=save_user_address]')
      end
    end

    context 'as a User' do
      before do
        user = create(:user)
        Spree::Order.last.update_column :user_id, user.id
        allow_any_instance_of(Spree::OrdersController).to receive_messages(try_spree_current_user: user)
        allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: user)
        click_button 'Checkout'
      end

      it 'is displayed' do
        expect(page).to have_css('[data-hook=save_user_address]')
      end
    end
  end

  context 'when order is completed' do
    let!(:user) { create(:user) }
    let!(:order) { OrderWalkthrough.up_to(:payment) }

    before do
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: user)
      allow_any_instance_of(Spree::OrdersController).to receive_messages(try_spree_current_user: user)

      visit spree.checkout_state_path(:payment)
      click_button 'Save and Continue'
    end

    it 'displays a thank you message' do
      expect(page).to have_content(Spree.t(:thank_you_for_your_order).gsub(/[[:space:]]+/, ' '))
    end

    it 'does not display a thank you message on that order future visits' do
      visit spree.order_path(order)
      expect(page).not_to have_content(Spree.t(:thank_you_for_your_order))
    end
  end

  context "order's address is outside the default included tax zone" do
    context 'so that no taxation applies to its product' do
      before do
        usa = Spree::Country.find_by(name: 'United States of America')
        north_america_zone = create(:zone,
                                    name: 'North America',
                                    kind: 'country',
                                    default_tax: true).tap do |zone|
          zone.members << create(:zone_member, zoneable: usa)
        end

        australia = create(:country,
                           name: 'Australia',
                           iso: 'AU',
                           iso_name: 'AUSTRALIA',
                           iso3: 'AUS',
                           states_required: true).tap do |country|
          country.states << create(:state,
                                   name: 'New South Wales',
                                   abbr: 'NSW')
        end
        australia_zone = create(:zone,
                                name: 'Australia',
                                kind: 'country',
                                default_tax: false).tap do |zone|
          zone.members << create(:zone_member, zoneable: australia)
        end

        default_tax_category = create(:tax_category, name: 'Default', is_default: true)

        create(:shipping_method,
               name: 'Default',
               display_on: 'both',
               zones: [australia_zone],
               tax_category: default_tax_category).tap do |sm|
          sm.calculator.preferred_amount = 10
          sm.calculator.preferred_currency = Spree::Config[:currency]
          sm.calculator.save
        end

        create(:tax_rate,
               name: 'USA included',
               amount: 0.23,
               zone: north_america_zone,
               tax_category: default_tax_category,
               show_rate_in_label: true,
               included_in_price: true)

        create(:product, name: 'Spree Bag', price: 100, tax_category: default_tax_category)
        create(:product, name: 'Spree T-Shirt', price: 100, tax_category: default_tax_category)
      end

      it 'correctly displays other product taxless price which has been added to cart later' do
        visit spree.root_path

        click_link 'Spree Bag'
        click_on 'Add To Cart'
        click_on 'Checkout'

        fill_in 'order_email', with: 'test@example.com'

        within '#checkout_form_address' do
          address = 'order_bill_address_attributes'

          fill_in "#{address}_firstname", with: 'John'
          fill_in "#{address}_lastname", with: 'Doe'
          fill_in "#{address}_address1", with: '199 George Street'
          fill_in "#{address}_city", with: 'Sydney'
          select 'Australia', from: "#{address}_country_id"
          select 'New South Wales', from: "#{address}_state_id"
          fill_in "#{address}_zipcode", with: '2000'
          fill_in "#{address}_phone", with: '123456789'
        end
        click_on 'Save and Continue'

        visit spree.root_path

        click_link 'Spree T-Shirt'
        click_on 'Add To Cart'

        expect(page).not_to have_content('$100.00')
        expect(page.all('td.cart-item-price', minimum: 2)).to all(have_content('$81.30'))
      end
    end
  end

  context 'user has store credits', js: true do
    let(:bogus) { create(:credit_card_payment_method) }
    let(:store_credit_payment_method) { create(:store_credit_payment_method) }
    let(:user) { create(:user) }
    let(:order) { OrderWalkthrough.up_to(:payment) }

    let(:prepare_checkout!) do
      order.update(user: user)
      allow(order).to receive_messages(available_payment_methods: [bogus, store_credit_payment_method])

      allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: user)
      allow_any_instance_of(Spree::OrdersController).to receive_messages(try_spree_current_user: user)
      visit spree.checkout_state_path(:payment)
    end

    context 'when not all Store Credits are used' do
      let!(:store_credit) { create(:store_credit, user: user) }
      let!(:additional_store_credit) { create(:store_credit, user: user, amount: 13) }

      before { prepare_checkout! }

      it 'page has data for (multiple) Store Credits' do
        expect(page).to have_selector('[data-hook="checkout_payment_store_credit_available"]')
        expect(page).to have_selector('button[name="apply_store_credit"]')

        amount = Spree::Money.new(store_credit.amount_remaining + additional_store_credit.amount_remaining)
        expect(page).to have_content(Spree.t('store_credit.available_amount', amount: amount))
      end

      it 'apply store credits button should move checkout to next step if amount is sufficient' do
        click_button 'Apply Store Credit'
        expect(page).to have_current_path(spree.order_path(order))
        expect(page).to have_content(Spree.t('order_processed_successfully'))
      end

      it 'apply store credits button should wait on payment step for other payment' do
        store_credit.update(amount_used: 145)
        additional_store_credit.update(amount_used: 12)
        click_button 'Apply Store Credit'

        expect(page).to have_current_path(spree.checkout_state_path(:payment))
        amount = Spree::Money.new(store_credit.amount_remaining + additional_store_credit.amount_remaining)
        remaining_amount = Spree::Money.new(order.total - amount.money.to_f)
        expect(page).to have_content(Spree.t('store_credit.applicable_amount', amount: amount))
        expect(page).to have_content(Spree.t('store_credit.additional_payment_needed', amount: remaining_amount))
        expect(page).to have_content(Spree.t('store_credit.remove'))
      end

      context 'remove store credits payments' do
        before do
          store_credit.update(amount: 5)
          additional_store_credit.update(amount: 5)
          click_button 'Apply Store Credit'
        end

        it 'remove store credits button should remove store_credits' do
          click_button 'Remove Store Credit'
          expect(page).to have_current_path(spree.checkout_state_path(:payment))
          expect(page).to have_content(Spree.t('store_credit.available_amount', amount: order.display_total_available_store_credit))
          expect(page).to have_selector('button[name="apply_store_credit"]')
        end
      end
    end

    context 'when all Store Credits are used' do
      before do
        create(:store_credit, user: user, amount_used: 150)
        prepare_checkout!
      end

      it 'page has no data for Store Credits when all Store Credits are used' do
        expect(page).not_to have_selector('[data-hook="checkout_payment_store_credit_available"]')
        expect(page).not_to have_selector('button[name="apply_store_credit"]')
      end
    end
  end

  def fill_in_address
    address = 'order_bill_address_attributes'
    fill_in "#{address}_firstname", with: 'Ryan'
    fill_in "#{address}_lastname", with: 'Bigg'
    fill_in "#{address}_address1", with: '143 Swan Street'
    fill_in "#{address}_city", with: 'Richmond'
    select country.name, from: "#{address}_country_id"
    select state.name, from: "#{address}_state_id"
    fill_in "#{address}_zipcode", with: '12345'
    fill_in "#{address}_phone", with: '(555) 555-5555'
  end

  def add_mug_to_cart
    add_to_cart(mug.name)
  end
end
