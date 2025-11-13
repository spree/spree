require 'spec_helper'

describe 'Checkout steps (address and delivery)' do
  let(:order) { create(:order_with_line_items, user_id: nil, store: store) }
  let!(:country) { create(:country) }
  let(:store) { Spree::Store.default }

  describe 'when new address is added after address step was completed' do
    let(:user) { create(:user_with_addresses) }

    before do
      order.update(user: user)
      order.ship_address = order.bill_address = user.ship_address
      order.save
      login_as(user, scope: :user)
    end

    it 'should not skip delivery step', js: true do
      # Complete address step
      visit "/checkout/#{order.token}"
      click_on 'Save and Continue'
      expect(page).to have_content('Delivery method')
      expect(page).to have_content(Spree::ShippingMethod.first.name)

      # Back to address step
      click_on 'Address'
      choose 'Add'
      fill_in_address_form('address_country_id')
      click_on 'Save'
      click_on 'Save and Continue'

      # Check if we are on delivery step
      expect(page).to have_content('Delivery method')
      expect(page).to have_content(Spree::ShippingMethod.first.name)
      expect(page).to have_content('Guest Guestovski')
      expect(page).to have_content('Bul ASNOM, 77')
      expect(page).to have_content('Skopje')
      expect(page).to have_content('77777')
      expect(page).to have_content(country.name)
    end
  end

  it 'includes order_state_lock_version hidden field on every step of checkout', js: true do
    visit "/checkout/#{order.token}"
    expect(page).to have_field(id: 'order_state_lock_version', type: :hidden, with: '0')
    fill_in 'Email', with: 'guest@mail.com'
    fill_in_address_form('order_ship_address_attributes_country_id')
    click_on 'Save and Continue'
    expect(page).to have_field(id: 'order_state_lock_version', type: :hidden, with: '1')
    click_on 'Save and Continue'
    expect(page).to have_field(id: 'order_state_lock_version', type: :hidden, with: '2')
  end

  context 'as a guest user' do
    it 'should show empty address form' do
      visit "/checkout/#{order.token}"
      fill_in 'Email', with: 'guest@mail.com'
      fill_in_address_form('order_ship_address_attributes_country_id')
      click_on 'Save and Continue'
      expect(page).to have_content('Delivery method')
      expect(page).to have_content(Spree::ShippingMethod.first.name)
      expect(page).to have_content('Guest Guestovski')
      expect(page).to have_content('Bul ASNOM, 77')
      expect(page).to have_content('Skopje')
      expect(page).to have_content('77777')
      expect(page).to have_content(country.name)
      click_on 'Save and Continue'
      expect(page).to have_content('Billing Address')
    end

    context 'with promotion', js: true do
      let(:promotion) { create(:promotion, stores: [store], code: :welcomepromo) }

      before do
        order.update!(email: nil, user: nil)

        calculator = Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10)
        Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator, promotion: promotion)

        Spree::Promotion::Rules::FirstOrder.create!(promotion: promotion)
      end

      it 'allows to apply first order coupon when user fills in email' do
        visit "/checkout/#{order.token}"
        fill_in 'Email', with: 'guest@mail.com'
        fill_in 'coupon_code', with: promotion.code

        click_on 'Apply'

        expect(page).to have_content('The coupon code was successfully applied to your order.')

        fill_in_address_form('order_ship_address_attributes_country_id')

        click_on 'Save and Continue'

        expect(page).to have_content(promotion.code.upcase)
      end

      it 'saves user email when user applies first order coupon' do
        visit "/checkout/#{order.token}"
        fill_in 'Email', with: 'guest@mail.com'
        fill_in 'coupon_code', with: promotion.code

        click_on 'Apply'
        wait_for_turbo

        refresh

        expect(page).to have_field('Email', with: 'guest@mail.com')
      end

      context 'with coupon codes' do
        let!(:promotion) { create(:promotion, stores: [store], name: '10% OFF', code: nil, multi_codes: true, number_of_codes: 1) }
        let!(:action) { Spree::Promotion::Actions::CreateAdjustment.create(promotion: promotion, calculator: calculator) }

        let(:calculator) { create(:flat_percent_item_total_calculator, preferred_flat_percent: 10) }

        let(:coupon_code) { promotion.coupon_codes.first }

        it 'uses the coupon code on the order' do
          visit "/checkout/#{order.token}"

          fill_in 'Email', with: 'guest@mail.com'
          fill_in 'coupon_code', with: coupon_code.code
          click_on 'Apply'

          expect(page).to have_content('The coupon code was successfully applied to your order.')

          expect(page).to have_text('Promotion (10% OFF)')

          expect(order.promotions).to contain_exactly(promotion)
          expect(coupon_code.reload).to be_used
          expect(coupon_code.order).to eq(order)
        end
      end

      describe 'mobile view' do
        before do
          page.driver.browser.manage.window.resize_to(390, 844)
        end

        after do
          page.driver.browser.manage.window.resize_to(1440, 900)
        end

        context 'when coupon is applied' do
          it 'updates the order total' do
            visit "/checkout/#{order.token}"
            fill_in 'Email', with: 'guest@mail.com'

            expect do
              click_on 'toggle-order-summary'
              fill_in 'coupon_code', with: promotion.code

              click_on 'Apply'
              wait_for_turbo
              click_on 'toggle-order-summary'
            end.to change { find('#summary-order-total').text }.from('$110.00').to('$109.00')
          end
        end

        context 'when coupon is removed' do
          before do
            order.update(email: 'guest@mail.com')
            promotion.activate({ order: order })
            order.update_with_updater!
          end

          it 'updates the order total' do
            visit "/checkout/#{order.token}"

            expect do
              click_on 'toggle-order-summary'
              click_on 'remove-promotion'

              wait_for_turbo
              click_on 'toggle-order-summary'
            end.to change { find('#summary-order-total').text }.from('$109.00').to('$110.00')
          end
        end
      end
    end
  end

  context 'as a signed in user with addresses' do
    let(:user) { create(:user_with_addresses) }

    before do
      order.update(user: user)
      order.ship_address = order.bill_address = user.ship_address
      order.save
      login_as(user, scope: :user)
    end

    context 'choosing the existing address' do
      it 'displays the address' do
        visit "/checkout/#{order.token}"
        expect(page).to have_content(user.email)
        expect(page).to have_content(user.shipping_address.firstname)
        expect(page).to have_content(user.shipping_address.lastname)
        expect(page).to have_content(user.shipping_address.address1)
        expect(page).to have_content(user.shipping_address.address2)
        expect(page).to have_content(user.shipping_address.city)
        expect(page).to have_content(user.shipping_address.zipcode)
        choose "order_ship_address_id_#{user.shipping_address.id}"
        click_on 'Save and Continue'
        expect(page).to have_content(Spree::ShippingMethod.first.name)
      end

      it 'can update the address', js: true do
        visit "/checkout/#{order.token}"
        choose "order_ship_address_id_#{user.shipping_address.id}"
        within "turbo-frame#address_#{user.shipping_address.id}" do
          click_on 'Edit'
          fill_in 'City', with: 'New York'
          click_on 'Update'
        end
        expect(page).to have_content('New York')
      end
    end

    context 'choosing add new address', js: true do
      it 'displays new address form' do
        visit "/checkout/#{order.token}"
        choose 'Add'
        expect(page).to have_field('Phone', with: user.phone)
        fill_in_address_form('address_country_id')
        click_on 'Save'
        click_on 'Save and Continue'
        expect(page).to have_content(user.email)
        expect(page).to have_content(user.shipping_address.firstname)
        expect(page).to have_content(user.shipping_address.lastname)
        expect(page).to have_content(user.shipping_address.address1)
        expect(page).to have_content(user.shipping_address.address2)
        expect(page).to have_content(user.shipping_address.city)
        expect(page).to have_content(user.shipping_address.zipcode)
        expect(page).to have_content(Spree::ShippingMethod.first.name)
      end
    end
  end

  context 'as a signed in user without addresses' do
    let(:user) { create(:user) }

    before do
      order.update(user: user, bill_address: nil, ship_address: nil)
      login_as(user, scope: :user)
    end

    it 'should allow to input address' do
      visit "/checkout/#{order.token}"
      expect(page).to have_content(user.email)
      expect(page).to have_content('Shipping Address')
      expect(page).to have_field('First Name', with: user.first_name)
      expect(page).to have_field('Last Name', with: user.last_name)
      fill_in_address_form('order_ship_address_attributes_country_id')
      click_on 'Save and Continue'
      expect(page).to have_content(user.email)
      expect(page).to have_content('Guest')
      expect(page).to have_content('Guestovski')
      expect(page).to have_content('Bul ASNOM')
      expect(page).to have_content('77')
      expect(page).to have_content('Skopje')
      expect(page).to have_content('77777')
      expect(page).to have_content(Spree::ShippingMethod.first.name)
    end

    context 'when user has empty phone number' do
      before do
        user.update_attribute(:phone, nil)
        user.reload
      end

      it 'should set ship address phone as user phone' do
        visit "/checkout/#{order.token}"
        expect(page).to have_field('Phone', text: '')
        fill_in_address_form('order_ship_address_attributes_country_id')
        click_on 'Save and Continue'
        expect(user.reload.phone).to eq(order.reload.ship_address.phone)
      end
    end

    context 'when user has phone number' do
      before do
        user.update_attribute(:phone, '+1 522-512-519')
        user.reload
      end

      it 'phone field should be prefilled' do
        visit "/checkout/#{order.token}"
        expect(page).to have_field('Phone', with: user.phone)
      end

      it 'should not set changed ship address phone as user phone' do
        expect do
          visit "/checkout/#{order.token}"
          fill_in_address_form('order_ship_address_attributes_country_id')
          click_on 'Save and Continue'
        end.not_to change { user.phone }
      end
    end
  end

  describe 'delivery step', js: true do
    let(:user) { create(:user_with_addresses) }
    let!(:promotion) { create(:free_shipping_promotion, code: 'freeshipping') }
    let!(:order) { create(:order_with_line_items, line_items_count: 1, user: user, ship_address: user.ship_address, bill_address: user.ship_address) }
    let!(:shipping_method) do
      create(:shipping_method, name: 'Shipping Method', code: 'shipping_method', calculator: create(:shipping_calculator, preferred_amount: 15))
    end
    let!(:other_shipping_method) do
      create(
        :shipping_method,
        name: 'Other Shipping Method',
        code: 'other_shipping_method',
        calculator: create(:shipping_calculator).tap do |c|
                      c.preferred_amount = 20
                      c.save!
                    end
      )
    end

    describe 'mobile view' do
      before do
        page.driver.browser.manage.window.resize_to(390, 844)
        login_as(user, scope: :user)
      end

      after do
        page.driver.browser.manage.window.resize_to(1440, 900)
      end

      context 'switching shipping methods' do
        it 'updates order total' do
          visit "/checkout/#{order.token}"
          choose "order_ship_address_id_#{user.shipping_address.id}"
          click_on 'Save and Continue'

          expect(find('#summary-order-total')).to have_content('$29.99')

          page.find("input[data-cost='$15.00']").click
          wait_for_turbo
          expect(find('#summary-order-total')).to have_content('$34.99')

          page.find("input[data-cost='$20.00']").click
          wait_for_turbo
          expect(find('#summary-order-total')).to have_content('$39.99')
        end
      end
    end

    # Regression V-1050
    context 'with free shipping promotion applied' do
      before { login_as(user, scope: :user) }

      it 'returns Shipping: Free & valid order total ammount' do
        visit "/checkout/#{order.token}"
        choose "order_ship_address_id_#{user.shipping_address.id}"
        click_on 'Save and Continue'

        expect(page).to have_selector("input[data-cost='$10.00'][checked='checked']")
        expect(page).to have_selector("input[data-cost='$15.00']")

        fill_in 'coupon_code', with: promotion.code
        click_on 'Apply'

        expect(page).to have_content('The coupon code was successfully applied to your order.')
        within('div.summary-content') do
          expect(page).to have_content('Free')
          expect(page).to have_content("#{Spree.t(:total)}\nUSD $19.99")
        end

        page.find("input[data-cost='$15.00']").click

        within('div.summary-content') do
          expect(page).to have_content('Free')
          expect(page).to have_content("#{Spree.t(:total)}\nUSD $19.99")
        end
      end
    end

    context 'when all items have track inventory disabled' do
      before do
        login_as(user, scope: :user)
        order.variants.each do |variant|
          variant.stock_items.delete_all
        end
        order.variants.each do |variant|
          variant.update(track_inventory: false)
        end
      end

      it 'still allows to checkout' do
        visit "/checkout/#{order.token}"
        choose "order_ship_address_id_#{user.shipping_address.id}"
        click_on 'Save and Continue'

        expect(page).to have_content('Delivery')
        expect(page).to have_content(Spree::ShippingMethod.first.name)

        page.find("input[data-cost='$15.00']").click

        expect(page).to have_content('Payment')
      end
    end
  end

  describe 'payment step', js: true do
    let(:user) { create(:user_with_addresses) }
    let!(:order) { create(:order_with_line_items, line_items_count: 1, user: user, ship_address: user.ship_address, bill_address: user.ship_address) }
    let!(:shipping_method) do
      create(:shipping_method, name: 'Shipping Method', code: 'shipping_method', calculator: create(:shipping_calculator, preferred_amount: 15))
    end

    before do
      login_as(user, scope: :user)
    end

    it 'allows to change billing address' do
      visit "/checkout/#{order.token}"
      choose "order_ship_address_id_#{user.shipping_address.id}"
      click_on 'Save and Continue'
      page.find("input[data-cost='$15.00']").click
      click_on 'Save and Continue'

      expect(page).to have_content('Shipping Method · $15.00')
      expect(page).to have_content("Subtotal:\n$19.99")
      expect(page).to have_content("Shipping:\n$15.00")
      expect(page).to have_content("Total\nUSD $34.99")

      uncheck 'Use Shipping Address'
      fill_in_address_form('order_bill_address_attributes_country_id')
    end

    describe 'mobile view' do
      before do
        page.driver.browser.manage.window.resize_to(390, 844)
      end

      after do
        page.driver.browser.manage.window.resize_to(1440, 900)
      end

      it 'allows to change billing address' do
        visit "/checkout/#{order.token}"
        choose "order_ship_address_id_#{user.shipping_address.id}"
        click_on 'Save and Continue'
        page.find("input[data-cost='$15.00']").click
        click_on 'Save and Continue'

        expect(page).to have_content('Shipping Method · $15.00')
        expect(page).to have_content("Show\norder summary\n$34.99")
        click_on 'toggle-order-summary'
        expect(page).to have_content("Subtotal:\n$19.99")
        expect(page).to have_content("Shipping:\n$15.00")
        expect(page).to have_content("Total\nUSD $34.99")

        uncheck 'Use Shipping Address'
        fill_in_address_form('order_bill_address_attributes_country_id')
      end
    end
  end

  context 'login from checkout' do
    before do
      order.update(ship_address: nil, bill_address: nil)
    end

    context 'user without addresses', js: true do
      let(:user) { create(:user) }

      it 'signs in an shows address form' do
        login_from_checkout
        expect(page).to have_content('Shipping Address')

        # fill in address
        fill_in 'Address', with: 'Bul ASNOM'
        fill_in 'Address (contd.)', with: '77'
        fill_in 'City', with: 'Skopje'
        fill_in 'Zip Code', with: '77777'
        select country.name, from: 'order_ship_address_attributes_country_id'
        click_on 'Save and Continue'
        wait_for_turbo

        expect(page).to have_content('Delivery method')
      end
    end

    context 'user with addresses', js: true do
      let(:user) { create(:user_with_addresses) }

      it 'signs in and shows address book' do
        login_from_checkout
        expect(page).to have_text('Shipping Address')
        first_address = user.addresses.first
        expect(page).to have_text(first_address.first_name)
        expect(page).to have_text(first_address.last_name)
        expect(page).to have_text(first_address.address1)
        expect(page).to have_text(first_address.address2)
        expect(page).to have_text(first_address.city)
        expect(page).to have_text(first_address.zipcode)

        second_address = user.addresses.second
        expect(page).to have_text(second_address.first_name)
        expect(page).to have_text(second_address.last_name)
        expect(page).to have_text(second_address.address1)
        expect(page).to have_text(second_address.address2)
        expect(page).to have_text(second_address.city)
        expect(page).to have_text(second_address.zipcode)
      end
    end

    context 'when order has some of the items backordered', js: true do
      let(:user) { create(:user) }

      before do
        order.variants.first.stock_items.first.update(backorderable: true, count_on_hand: 0)

        order.reload
      end

      it 'shows information to the customer that the delivery may be delayed' do
        login_from_checkout
        fill_in_address_form('order_ship_address_attributes_country_id')
        click_on 'Save and Continue'
        expect(page).to have_content('Some products in your cart will be dispatched a bit later than the rest of your order')
      end

      it 'has only one shipping method' do
        login_from_checkout
        fill_in_address_form('order_ship_address_attributes_country_id')
        click_on 'Save and Continue'
        wait_for_turbo

        expect(page).to have_content(Spree::ShippingMethod.first.name).once
      end
    end

    context 'when order has items without shipping rate on address step', js: true do
      let(:user) { create(:user) }
      let(:order) { create(:order_with_line_items, line_items_count: 2, user_id: nil) }

      context 'when order has one invalid item' do
        before do
          allow_any_instance_of(Spree::Order).to receive(:next!).and_return(false)
          allow_any_instance_of(Spree::Order).to receive(:line_items_without_shipping_rates).and_return(order.line_items.limit(1))
          order.reload
        end

        it 'shows information to the customer that one item cant be delivered' do
          login_from_checkout
          fill_in_address_form('order_ship_address_attributes_country_id')
          click_on 'Save and Continue'
          wait_for_turbo

          expect(page).to have_content(Spree.t(:shipping_not_available))
          expect do
            click_on 'Continue to checkout'
            wait_for_turbo
          end.to change { order.line_items.reload.count }.by(-1)
        end
      end

      context 'when order has all invalid items' do
        before do
          allow_any_instance_of(Spree::Order).to receive(:next!).and_return(false)
          allow_any_instance_of(Spree::Order).to receive(:line_items_without_shipping_rates).and_return(order.line_items)
          order.reload
        end

        it 'shows information to the customer that one item cant be delivered' do
          login_from_checkout
          fill_in_address_form('order_ship_address_attributes_country_id')
          click_on 'Save and Continue'
          expect(page).to have_content('Shipping not available')
        end
      end
    end
  end

  describe 'completing order' do
    let(:address) { create(:address) }
    let!(:order) do
      create(
        :order_with_line_items,
        line_items_count: 1,
        state: :payment,
        user: nil,
        email: 'test@example.com',
        ship_address: address,
        bill_address: address
      )
    end
    let!(:shipping_method) do
      create(:shipping_method, name: 'Shipping Method', code: 'shipping_method', calculator: create(:shipping_calculator))
    end

    context 'when order is already completed and someone else views the order' do
      let!(:order) do
        create(
          :order_with_line_items,
          line_items_count: 1,
          state: :complete,
          completed_at: Time.current,
          user: nil,
          email: 'test@example.com',
          ship_address: address,
          bill_address: address
        )
      end

      it 'should not login user' do
        visit '/account'
        expect(page.current_path).to eq('/user/sign_in')

        visit "/checkout/#{order.token}/complete?payment_intent=xxx&payment_intent_client_secret=yyy"

        expect(page).to have_content("Thanks #{address.first_name} for your order!")

        visit '/account'
        expect(page.current_path).to eq('/user/sign_in')
      end
    end

    describe 'checkout links' do
      let!(:link) { create(:page_link, parent: store) }

      it 'shows checkout links' do
        visit "/checkout/#{order.token}"
        expect(page).to have_content(link.label)
      end
    end
  end

  def login_from_checkout
    visit "/checkout/#{order.token}"
    click_on 'Login'
    fill_in 'user_email', with: user.email
    fill_in 'user_password', with: user.password
    click_button 'login-button'
  end

  def fill_in_address_form(country_field_name)
    fill_in 'First Name', with: 'Guest'
    fill_in 'Last Name', with: 'Guestovski'
    fill_in 'Address', with: 'Bul ASNOM'
    fill_in 'Address (contd.)', with: '77'
    fill_in 'City', with: 'Skopje'
    fill_in 'Zip Code', with: '77777'
    fill_in 'Phone', with: '522-512-519'
    select country.name, from: country_field_name
  end
end
