require 'spec_helper'

describe 'Checkout', type: :feature, inaccessible: true, js: true do
  include_context 'checkout setup'

  let(:country) { create(:country, name: 'United States of America', iso_name: 'UNITED STATES') }
  let(:state) { create(:state, name: 'Alabama', abbr: 'AL', country: country) }
  let(:store) { Spree::Store.default }

  context 'visitor makes checkout as guest without registration' do
    before do
      stock_location.stock_items.update_all(count_on_hand: 1)
    end

    context 'defaults to use billing address' do
      before do
        add_mug_to_cart
        Spree::Order.last.update_column(:email, 'test@example.com')
        click_link 'checkout'
      end

      it 'defaults checkbox to checked' do
        expect(page).to have_checked_field(id: 'order_use_billing', visible: false)
      end

      it 'remains checked when used and visitor steps back to address step' do
        fill_in_address
        expect(page).to have_checked_field(id: 'order_use_billing', visible: false)
      end
    end

    # Regression test for #4079
    context 'persists state when on address page' do
      before do
        add_mug_to_cart
        click_link 'checkout'
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

        add_mug_to_cart
        click_link 'checkout'
        fill_in 'order_email', with: 'test@example.com'
      end

      it 'does not break the per-item shipping method calculator', js: true do
        fill_in_address

        click_button 'Save and Continue'
        expect(page).not_to have_content("undefined method `promotion'")
        click_button 'Save and Continue'
        page.has_text? ('SHIPPING: $10.00')
      end
    end

    # Regression test for #4306
    context 'free shipping' do
      before do
        add_mug_to_cart
        click_link 'checkout'
        fill_in 'order_email', with: 'test@example.com'
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
      click_link 'checkout'
      fill_in 'order_email', with: 'test@example.com'

      expect(page).to have_field(id: 'order_state_lock_version', type: :hidden, with: '0')

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
      fill_in_credit_card_info(invalid: true)
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
      click_link 'checkout'
      fill_in 'order_email', with: 'test@example.com'

      fill_in_address

      click_button 'Save and Continue'
      click_button 'Save and Continue'
      fill_in_credit_card_info
      click_button 'Save and Continue'

      expect(find('#checkout')).to have_button(class: 'btn-primary', value: 'Place Order')
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

    it 'checks if payment button will be disabled on submit', js: true do
      visit spree.checkout_state_path(:payment)

      expect(page).to have_selector('input.btn-primary.checkout-content-save-continue-button[data-disable-with]')
    end

    it 'checks if confirm button will be disabled on submit', js: true do
      order.payments << create(:payment, amount: order.amount)
      visit spree.checkout_state_path(:confirm)

      expect(page).to have_selector('input.btn-primary.checkout-content-save-continue-button[data-disable-with]')
    end
  end

  context 'when several payment methods are available', js: true do
    let!(:current_store) { create(:store, default: true) }

    before do
      order = OrderWalkthrough.up_to(:payment)
      order.user = create(:user)
      order.update_with_updater!

      allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: order.user)

      visit spree.checkout_state_path(:payment)
    end

    it 'the credit card payment method should be visible' do
      expect(page).to have_css("#payment_method_#{credit_card_payment.id}")
    end

    it 'the fields for the other payment methods should be hidden' do
      payment_method_css = '#payment_method_'
      expect(page).to have_css("#{payment_method_css}#{credit_card_payment.id}")
      expect(page).to have_css("#{payment_method_css}#{check_payment.id}", visible: :hidden)
    end

    it 'only returns supported payment method of current store' do
      expect(page).not_to have_css("#payment_method_#{unsupported_payment.id}", visible: :hidden)
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

    it 'allows user to enter a new source' do
      find('label', text: 'Add a new card').click

      fill_in_credit_card_info

      expect { click_on 'Save and Continue' }.to change { Spree::CreditCard.count }.by 1

      click_on 'Place Order'

      expect(page).to have_content(Spree.t(:order_success).gsub(/[[:space:]]+/, ' '))
      expect(page).to have_current_path(spree.order_path(Spree::Order.last))
    end
  end

  # regression for #2921
  context 'goes back from payment to add another item', js: true do
    let!(:bag) { create(:product, name: 'RoR Bag') }

    it 'transit nicely through checkout steps again' do
      add_mug_to_cart
      click_on 'checkout'
      fill_in 'order_email', with: 'test@example.com'
      fill_in_address
      click_on 'Save and Continue'
      click_on 'Save and Continue'
      expect(page).to have_current_path(spree.checkout_state_path('payment'))

      add_to_cart(bag)

      click_on 'checkout'
      click_on 'Save and Continue'
      click_on 'Save and Continue'
      fill_in_credit_card_info
      click_on 'Save and Continue'
      click_on 'Place Order'

      expect(page).to have_current_path(spree.order_path(Spree::Order.last))
    end
  end

  context 'from payment step customer goes back to cart', js: true do
    before do
      add_mug_to_cart
      click_on 'checkout'
      fill_in 'order_email', with: 'test@example.com'
      fill_in_address
      click_on 'Save and Continue'
      click_on 'Save and Continue'
      expect(page).to have_current_path(spree.checkout_state_path('payment'))
    end

    context 'and updates line item quantity and try to reach payment page' do
      let(:cart_quantity) { 3 }

      before do
        visit spree.cart_path
        within '.shopping-cart-item' do
          find('.shopping-cart-item-quantity .shopping-cart-item-quantity-input').fill_in with: cart_quantity
        end
        find('body').click
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
        add_to_cart(bag)
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

  context 'if coupon promotion, submits coupon along with payment', js: true do
    let!(:promotion) { Spree::Promotion.create(name: 'Huhuhu', code: 'huhu') }
    let!(:calculator) { Spree::Calculator::FlatPercentItemTotal.create(preferred_flat_percent: '10') }
    let!(:action) { Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator) }

    before do
      promotion.actions << action
      add_mug_to_cart
    end

    it 'makes sure payment reflects order total with discounts' do
      find('#order_coupon_code').fill_in with: promotion.code
      find('#shopping-cart-coupon-code-button').click
      click_on 'checkout'

      fill_in 'order_email', with: 'test@example.com'
      fill_in_address

      click_on 'Save and Continue'
      click_on 'Save and Continue'

      expect(page).to have_current_path(spree.checkout_state_path('payment'))

      fill_in_credit_card_info
      click_on 'Save and Continue'

      expect(page).to have_content(promotion.name.upcase)
      expect(Spree::Payment.first.amount.to_f).to eq Spree::Order.last.total.to_f
    end

    context 'invalid coupon' do
      it 'doesnt create a payment record' do
        find('#order_coupon_code').fill_in with: 'invalid'
        find('#shopping-cart-coupon-code-button').click

        expect(Spree::Payment.count).to eq 0
        expect(page).to have_content(Spree.t(:coupon_code_not_found))
      end
    end

    context "doesn't fill in coupon code input" do
      it 'advances just fine' do
        click_on 'checkout'
        expect(page).to have_current_path(spree.checkout_state_path('address'))
      end
    end

    context 'the promotion makes order free (downgrade it total to 0.0)' do
      let(:promotion2) { Spree::Promotion.create(name: 'test-7450', code: 'test-7450') }
      let(:calculator2) do
        Spree::Calculator::FlatRate.create(preferences: { currency: 'USD', amount: BigDecimal('99999') })
      end
      let(:action2) { Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator2) }

      before { promotion2.actions << action2 }

      context 'user choose to pay by card' do
        let(:bogus) { create(:credit_card_payment_method) }

        before do
          order = Spree::Order.last
          allow(order).to receive_messages(available_payment_methods: [bogus])
          allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
        end

        it 'move user to order succesfully placed page' do
          find('#order_coupon_code').fill_in(with: promotion2.code)
          find('#shopping-cart-coupon-code-button').click
          click_on 'checkout'

          fill_in 'order_email', with: 'test@example.com'
          fill_in_address

          click_on 'Save and Continue'
          click_on 'Save and Continue'

          expect(Spree::Order.last.total.to_f).to eq(0)
          expect(page).to have_current_path(spree.order_path(Spree::Order.last))
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
      click_on 'checkout'
    end

    after do
      Spree::Order.checkout_flow(&@old_checkout_flow)
    end

    it 'goes right payment step and place order just fine' do
      expect(page).to have_current_path(spree.checkout_state_path('payment'))

      fill_in_credit_card_info
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
        click_link 'checkout'
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
        click_link 'checkout'
      end

      it 'is displayed' do
        expect(page).to have_css('[data-hook=save_user_address]', visible: :hidden)
      end
    end
  end

  context 'when order is completed' do
    let!(:user) { create(:user) }
    let!(:order) { create(:order) }

    before do
      add_mug_to_cart
      click_on 'checkout'
      fill_in 'order_email', with: 'test@example.com'
      fill_in_address
      click_on 'Save and Continue'
      click_on 'Save and Continue'
    end

    it 'displays a thank you message' do
      fill_in_credit_card_info
      click_button 'Save and Continue'
      click_button 'Place Order'

      expect(page).to have_content(Spree.t(:order_success).gsub(/[[:space:]]+/, ' '))
    end

    it 'does not display a thank you message on that order future visits' do
      visit spree.order_path(order)
      expect(page).not_to have_content(Spree.t(:order_success))
    end
  end

  context "order's address is outside the default included tax zone" do
    context 'so that no taxation applies to its product' do
      let!(:bag) { create(:product, name: 'Spree Bag', price: 100, tax_category: default_tax_category) }
      let!(:shirt) { create(:product, name: 'Spree T-Shirt', price: 100, tax_category: default_tax_category) }
      let!(:default_tax_category) { create(:tax_category, name: 'Default', is_default: true) }

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


        create(:shipping_method,
               name: 'Default',
               display_on: 'both',
               zones: [australia_zone],
               tax_category: default_tax_category).tap do |sm|
          sm.calculator.preferred_amount = 10
          sm.calculator.preferred_currency = store.default_currency
          sm.calculator.save
        end

        create(:tax_rate,
               name: 'USA included',
               amount: 0.23,
               zone: north_america_zone,
               tax_category: default_tax_category,
               show_rate_in_label: true,
               included_in_price: true)
      end

      it 'correctly displays other product taxless price which has been added to cart later' do
        visit spree.root_path

        add_to_cart(bag)
        click_on 'checkout'

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

        add_to_cart(shirt)

        expect(page).not_to have_content('$100.00')
        expect(page.all('.shopping-cart-item-price', minimum: 2)).to all(have_content('$81.30'))
      end
    end
  end

  context 'user has store credits', js: true do

    shared_examples 'could not use store credit' do
      it 'page has no data for Store Credits' do
        expect(page).not_to have_selector('[data-hook="checkout_payment_store_credit_available"]')
        expect(page).not_to have_selector('button[name="apply_store_credit"]')
      end
    end


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
        expect(page).to have_content(Spree.t('store_credit.available_amount', amount: amount).strip_html_tags)
      end

      it 'apply store credits button should move checkout to next step if amount is sufficient' do
        click_button 'Apply'
        expect(page).to have_current_path(spree.order_path(order))
        expect(page).to have_content(Spree.t('order_success'))
      end

      it 'apply store credits button should wait on payment step for other payment' do
        store_credit.update(amount_used: 145)
        additional_store_credit.update(amount_used: 12)
        click_button 'Apply'

        expect(page).to have_current_path(spree.checkout_state_path(:payment))
        amount = Spree::Money.new(store_credit.amount_remaining + additional_store_credit.amount_remaining)
        remaining_amount = Spree::Money.new(order.total - amount.money.to_f)
        expect(page).to have_content(Spree.t('store_credit.applicable_amount', amount: amount).strip_html_tags)
        expect(page).to have_content(Spree.t('store_credit.additional_payment_needed', amount: remaining_amount).strip_html_tags)
        expect(page).to have_content(Spree.t('store_credit.remove').upcase)
      end

      context 'remove store credits payments' do
        before do
          store_credit.update(amount: 5)
          additional_store_credit.update(amount: 5)
          click_button 'Apply'
        end

        it 'remove store credits button should remove store_credits' do
          click_button 'Remove', match: :first
          expect(page).to have_current_path(spree.checkout_state_path(:payment))
          expect(page).to have_content(Spree.t('store_credit.available_amount', amount: order.display_total_available_store_credit).strip_html_tags)
          expect(page).to have_selector('button[name="apply_store_credit"]')
        end
      end
    end

    context 'when all Store Credits are used' do
      before do
        create(:store_credit, user: user, amount_used: 150)
        prepare_checkout!
      end

      it_behaves_like 'could not use store credit'
    end

    context 'when Store Credit Payment is not active' do
      before do
        create(:store_credit) { create(:store_credit, user: user) }
        store_credit_payment_method.update_attribute(:active, false)
        prepare_checkout!
      end

      it_behaves_like 'could not use store credit'
    end

    context 'when Store Credit Payment is not exist' do
      before do
        create(:store_credit) { create(:store_credit, user: user) }
        store_credit_payment_method.destroy
        prepare_checkout!
      end

      it_behaves_like 'could not use store credit'
    end
  end
end
