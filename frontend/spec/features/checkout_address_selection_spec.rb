require 'spec_helper'

describe 'Address selection during checkout', type: :feature, js: true do
  let!(:store) { create(:store, default: true) }
  let(:state) { Spree::State.all.first || create(:state) }

  describe 'guest user' do
    include_context 'checkout address book'
    before do
      click_button 'Checkout'
      fill_in 'order_email', with: 'guest@example.com'
      click_button 'Continue'
    end

    it 'sees billing address form' do
      within('#billing') do
        should_have_address_fields
        expect(page).not_to have_selector('.select_address')
      end
    end

    it 'sees shipping address form' do
      within('#shipping') do
        uncheck 'order_use_billing'
        should_have_address_fields
        expect(page).not_to have_selector('.select_address')
      end
    end
  end

  describe 'as authenticated user with saved addresses' do
    include_context 'checkout address book'

    before do
      @user = create(:user)
      @user.addresses << create(:address, address1: FFaker::Address.street_address, state: state, alternative_phone: nil)
      @user.save

      allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: @user)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(skip_state_validation?: true)

      click_button 'Checkout'
    end

    let(:billing) { build(:address, state: state) }
    let(:shipping) do
      build(:address, address1: FFaker::Address.street_address, state: state)
    end
    let(:user) { @user }

    it 'does not see billing or shipping address form' do
      expect(page).to have_css('#billing .inner', visible: :hidden)
      expect(page).to have_css('#shipping .inner', visible: :hidden)
    end

    it 'lists saved addresses for billing and shipping' do
      within('#billing .select_address') do
        user.addresses.each do |a|
          expect(page).to have_field("order_bill_address_id_#{a.id}")
        end
      end
      within('#shipping .select_address', visible: false) do
        user.addresses.each do |a|
          expect(page).to have_field("order_ship_address_id_#{a.id}", visible: false)
        end
      end
    end

    it 'saves 2 addresses for user if they are different', js: true do
      expect do
        within('#billing') do
          choose Spree.t('address_book.other_address')
          fill_in_address(billing)
        end
        within('#shipping') do
          uncheck 'order_use_billing'
          choose Spree.t('address_book.other_address')
          fill_in_address(shipping, :ship)
        end
        complete_checkout
      end.to change { user.addresses.count }.by(2)
    end

    it 'saves 1 address for user if they are the same' do
      expect do
        within('#billing') do
          choose Spree.t('address_book.other_address')
          fill_in_address(billing)
        end
        within('#shipping') do
          uncheck 'order_use_billing'
          choose Spree.t('address_book.other_address')
          fill_in_address(billing, :ship)
        end
        complete_checkout
      end.to change { user.addresses.count }.by(1)
    end

    describe 'when invalid address is entered', js: true do
      let(:address) do
        build(:address, firstname: nil, state: state)
      end

      # TODO: the JS error reporting isn't working with our current iteration
      # this is what this piece of code ('field is required') tests
      it 'shows address form with error' do
        within('#billing') do
          choose Spree.t('address_book.other_address')
          fill_in_address(address)
        end
        within('#shipping') do
          uncheck 'order_use_billing'
          choose Spree.t('address_book.other_address')
          fill_in_address(address, :ship)
        end
        click_button 'Save and Continue'

        bfirstname_message = page.find('#order_bill_address_attributes_firstname').native.attribute('validationMessage')
        sfirstname_message = page.find('#order_ship_address_attributes_firstname').native.attribute('validationMessage')

        expect(bfirstname_message).to eq('Please fill out this field.')
        expect(sfirstname_message).to eq('Please fill out this field.')
      end
    end

    describe 'entering 2 new addresses', js: true do
      it 'assigns 2 new addresses to order' do
        within('#billing') do
          choose Spree.t('address_book.other_address')
          fill_in_address(billing)
        end
        within('#shipping') do
          uncheck 'order_use_billing'
          choose Spree.t('address_book.other_address')
          fill_in_address(shipping, :ship)
        end
        complete_checkout
        expect(page).to have_content('processed successfully')
        within('#order > div.row.steps-data > div:nth-child(1)') do
          expect(page).to have_content('Billing Address')
          expect(page).to have_content(expected_address_format(billing))
        end
        within('#order > div.row.steps-data > div:nth-child(2)') do
          expect(page).to have_content('Shipping Address')
          expect(page).to have_content(expected_address_format(shipping))
        end
      end
    end

    describe 'using saved address for bill and new ship address', js: true do
      let(:shipping) do
        build(:address, address1: FFaker::Address.street_address,
                        state: state)
      end

      it 'saves 1 new address for user' do
        expect do
          address = user.addresses.first
          choose "order_bill_address_id_#{address.id}"
          within('#shipping') do
            uncheck 'order_use_billing'
            choose Spree.t('address_book.other_address')
            fill_in_address(shipping, :ship)
          end
          complete_checkout
        end.to change { user.addresses.count }.by(1)
      end

      it 'assigns addresses to orders' do
        address = user.addresses.first
        choose "order_bill_address_id_#{address.id}"
        within('#shipping') do
          uncheck 'order_use_billing'
          choose Spree.t('address_book.other_address')
          fill_in_address(shipping, :ship)
        end
        complete_checkout
        expect(page).to have_content('processed successfully')
        within('#order > div.row.steps-data > div:nth-child(1)') do
          expect(page).to have_content('Billing Address')
          expect(page).to have_content(expected_address_format(address))
        end
        within('#order > div.row.steps-data > div:nth-child(2)') do
          expect(page).to have_content('Shipping Address')
          expect(page).to have_content(expected_address_format(shipping))
        end
      end

      it 'sees form when new shipping address invalid' do
        address = user.addresses.first
        shipping = build(:address, address1: nil, state: state)
        choose "order_bill_address_id_#{address.id}"
        within('#shipping') do
          uncheck 'order_use_billing'
          choose Spree.t('address_book.other_address')
          fill_in_address(shipping, :ship)
        end
        click_button 'Save and Continue'

        saddress1_message = page.find('#order_ship_address_attributes_address1').native.attribute('validationMessage')
        expect(saddress1_message).to eq('Please fill out this field.')

        within('#billing') do
          expect(page).to have_checked_field(id: "order_bill_address_id_#{address.id}")
        end
      end
    end

    describe 'using saved address for billing and shipping', js: true do
      it 'addresseses to order' do
        address = user.addresses.first
        choose "order_bill_address_id_#{address.id}"
        check 'Use Billing Address'
        complete_checkout
        within('#order > div.row.steps-data > div:nth-child(1)') do
          expect(page).to have_content('Billing Address')
          expect(page).to have_content(expected_address_format(address))
        end
        within('#order > div.row.steps-data > div:nth-child(2)') do
          expect(page).to have_content('Shipping Address')
          expect(page).to have_content(expected_address_format(address))
        end
      end

      it 'does not add addresses to user' do
        expect do
          address = user.addresses.first
          choose "order_bill_address_id_#{address.id}"
          check 'Use Billing Address'
          complete_checkout
        end.not_to change { user.addresses.count }
      end
    end

    describe 'using saved address for ship and new bill address', js: true do
      let(:billing) do
        build(:address, address1: FFaker::Address.street_address, state: state, zipcode: '90210')
      end

      it 'saves 1 new address for user' do
        expect do
          address = user.addresses.first
          uncheck 'order_use_billing'
          choose "order_ship_address_id_#{address.id}"
          within('#billing') do
            choose Spree.t('address_book.other_address')
            fill_in_address(billing)
          end
          complete_checkout
        end.to change { user.addresses.count }.by(1)
      end

      it 'assigns addresses to orders' do
        address = user.addresses.first
        uncheck 'order_use_billing'
        choose "order_ship_address_id_#{address.id}"
        within('#billing') do
          choose Spree.t('address_book.other_address')
          fill_in_address(billing)
        end
        complete_checkout
        expect(page).to have_content('processed successfully')
        within('#order > div.row.steps-data > div:nth-child(1)') do
          expect(page).to have_content('Billing Address')
          expect(page).to have_content(expected_address_format(billing))
        end
        within('#order > div.row.steps-data > div:nth-child(2)') do
          expect(page).to have_content('Shipping Address')
          expect(page).to have_content(expected_address_format(address))
        end
      end

      # TODO: not passing because inline JS validation not working
      it 'sees form when new billing address invalid' do
        address = user.addresses.first
        billing = build(:address, address1: nil, state: state)
        uncheck 'order_use_billing'
        choose "order_ship_address_id_#{address.id}"
        within('#billing') do
          choose Spree.t('address_book.other_address')
          fill_in_address(billing)
        end
        click_button 'Save and Continue'

        baddress1_message = page.find('#order_bill_address_attributes_address1').native.attribute('validationMessage')
        expect(baddress1_message).to eq('Please fill out this field.')

        within('#shipping') do
          expect(page).to have_checked_field(id: "order_ship_address_id_#{address.id}")
        end
      end
    end

    describe 'entering address that is already saved', js: true do
      it 'does not save address for user' do
        expect do
          address = user.addresses.first
          uncheck 'order_use_billing'
          choose "order_ship_address_id_#{address.id}"
          within('#billing') do
            choose Spree.t('address_book.other_address')
            fill_in_address(address)
          end
          complete_checkout
        end.not_to change { user.addresses.count }
      end
    end
  end

  describe 'as authenticated user without saved addresses' do
    include_context 'checkout address book'

    let(:address) { create(:address, address1: FFaker::Address.street_address, state: state, alternative_phone: nil) }
    let(:user) { create(:user) }

    before do
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: user)
      allow_any_instance_of(Spree::CheckoutController).to receive_messages(skip_state_validation?: true)
    end

    describe 'with unchecked save my address', js: true do
      it 'does not add addresses to user' do
        expect do
          click_button 'Checkout'
          within('#billing') { fill_in_address(address) }
          uncheck 'save_user_address'
          complete_checkout
        end.not_to change { user.addresses.count }
      end

      it 'does see billing or shipping address form' do
        click_button 'Checkout'
        within('#billing') { fill_in_address(address) }
        uncheck 'save_user_address'
        complete_checkout
        user.reload.addresses

        add_to_cart(Spree::Product.last.name)
        click_button 'Checkout'

        within('#billing') do
          should_have_address_fields
          expect(page).not_to have_selector('.select_address')
        end
      end
    end

    describe 'with checked save my address', js: true do
      it 'adds addresses to user' do
        expect do
          click_button 'Checkout'
          within('#billing') { fill_in_address(address) }
          complete_checkout
        end.to change { user.addresses.count }.by(1)
      end

      it 'does not see billing or shipping address form' do
        click_button 'Checkout'
        within('#billing') { fill_in_address(address) }
        complete_checkout
        user.reload.addresses

        add_to_cart(Spree::Product.last.name)
        click_button 'Checkout'

        expect(page).to have_css('#billing .inner', visible: :hidden)
        expect(page).to have_css('#shipping .inner', visible: :hidden)
      end
    end
  end
end
