require 'spec_helper'

describe 'Address selection during checkout', type: :feature, js: true do
  let!(:store) { create(:store, default: true) }
  let(:state) { Spree::State.all.first || create(:state) }

  describe 'guest user' do
    include_context 'checkout address book'

    before do
      click_link 'checkout'
    end

    it 'sees billing address form' do
      within('#billing') do
        should_have_address_fields
        expect(page).not_to have_selector('.select_address')
      end
    end

    it 'sees shipping address form' do
      within('#shipping') do
        find('label', text: 'Use Billing Address').click
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

      click_link 'checkout'
    end

    let(:billing) { build(:address, state: state) }
    let(:shipping) do
      build(:address, address1: FFaker::Address.street_address, state: state)
    end
    let(:user) { @user }

    it 'does not see billing or shipping address form' do
      expect(page).not_to have_css('#billing .inner')
      expect(page).not_to have_css('#shipping .inner')
    end

    it 'lists saved addresses for billing and shipping' do
      within('#billing .select_address') do
        user.addresses.each do |a|
          expect(page).to have_field("order_bill_address_id_#{a.id}", visible: false)
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
        within('#billing .select_address') do
          find('label', text: 'Other address').click
        end
        within('#billing .inner') do
          fill_in_address(billing)
        end
        within('#shipping') do
          find('label', text: 'Use Billing Address').click
          find('label', text: 'Other address').click
          fill_in_address(shipping, :ship)
        end
        complete_checkout(billing)
      end.to change { user.addresses.count }.by(2)
    end

    it 'saves 1 address for user if they are the same' do
      expect do
        within('#billing') do
          find('label', text: 'Other address').click
        end
        within('#billing .inner') do
          fill_in_address(billing)
        end
        within('#shipping') do
          find('label', text: 'Use Billing Address').click
          find('label', text: 'Other address').click
          fill_in_address(billing, :ship)
        end
        complete_checkout(billing)
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
          find('label', text: 'Other address').click
          fill_in_address(address)
        end
        within('#shipping') do
          find('label', text: 'Use Billing Address').click
          find('label', text: 'Other address').click
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
          find('label', text: 'Other address').click
          fill_in_address(billing)
        end
        within('#shipping') do
          find('label', text: 'Use Billing Address').click
          find('label', text: 'Other address').click
          fill_in_address(shipping, :ship)
        end
        complete_checkout(billing)
        within first('[data-hook="order-ship-address"]') do
          expect(page).to have_content('SHIPPING ADDRESS')
          expect(page).to have_content(expected_address_format('SHIPPING ADDRESS', shipping))
        end
        within first('[data-hook="order-bill-address"]') do
          expect(page).to have_content('BILLING ADDRESS')
          expect(page).to have_content(expected_address_format('BILLING ADDRESS', billing))
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
          within("#billing .select_address #billing_address_#{address.id}") do
            find('label').click
          end
          within('#shipping') do
            find('label', text: 'Use Billing Address').click
            find('label', text: 'Other address').click
            fill_in_address(shipping, :ship)
          end
          complete_checkout(address)
        end.to change { user.addresses.count }.by(1)
      end

      it 'assigns addresses to orders' do
        address = user.addresses.first
        within("#billing .select_address #billing_address_#{address.id}") do
          find('label').click
        end
        within('#shipping') do
          find('label', text: 'Use Billing Address').click
          find('label', text: 'Other address').click
          fill_in_address(shipping, :ship)
        end
        complete_checkout(address)
        within first('[data-hook="order-ship-address"]') do
          expect(page).to have_content('SHIPPING ADDRESS')
          expect(page).to have_content(expected_address_format('SHIPPING ADDRESS', shipping))
        end
        within first('[data-hook="order-bill-address"]') do
          expect(page).to have_content('BILLING ADDRESS')
          expect(page).to have_content(expected_address_format('BILLING ADDRESS', address))
        end
      end

      it 'sees form when new shipping address invalid' do
        address = user.addresses.first
        shipping = build(:address, address1: nil, state: state)
        within("#billing .select_address #billing_address_#{address.id}") do
          find('label').click
        end
        within('#shipping') do
          find('label', text: 'Use Billing Address').click
          find('label', text: 'Other address').click
          fill_in_address(shipping, :ship)
        end
        click_button 'Save and Continue'

        saddress1_message = page.find('#order_ship_address_attributes_address1').native.attribute('validationMessage')
        expect(saddress1_message).to eq('Please fill out this field.')

        within('#billing') do
          expect(page).to have_checked_field(id: "order_bill_address_id_#{address.id}", visible: false)
        end
      end
    end

    describe 'using saved address for billing and shipping', js: true do
      it 'addresseses to order' do
        address = user.addresses.first
        within("#billing .select_address #billing_address_#{address.id}") do
          find('label').click
        end
        find('label', text: 'Use Billing Address').click
        complete_checkout(address)
        within first('[data-hook="order-ship-address"]') do
          expect(page).to have_content('SHIPPING ADDRESS')
          expect(page).to have_content(expected_address_format('SHIPPING ADDRESS', address))
        end
        within first('[data-hook="order-bill-address"]') do
          expect(page).to have_content('BILLING ADDRESS')
          expect(page).to have_content(expected_address_format('BILLING ADDRESS', address))
        end
      end

      it 'does not add addresses to user' do
        expect do
          address = user.addresses.first
          within("#billing .select_address #billing_address_#{address.id}") do
            find('label').click
          end
          find('label', text: 'Use Billing Address').click
          complete_checkout(address)
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
          find('label', text: 'Use Billing Address').click
          within("#shipping .select_address #shipping_address_#{address.id}") do
            find('label').click
          end
          within('#billing') do
            find('label', text: 'Other address').click
            fill_in_address(billing)
          end
          complete_checkout(address)
        end.to change { user.addresses.count }.by(1)
      end

      it 'assigns addresses to orders' do
        address = user.addresses.first
        find('label', text: 'Use Billing Address').click
        within("#shipping .select_address #shipping_address_#{address.id}") do
          find('label').click
        end
        within('#billing') do
          find('label', text: 'Other address').click
          fill_in_address(billing)
        end
        complete_checkout(address)
        within first('[data-hook="order-ship-address"]') do
          expect(page).to have_content('SHIPPING ADDRESS')
          expect(page).to have_content(expected_address_format('SHIPPING ADDRESS', address))
        end
        within first('[data-hook="order-bill-address"]') do
          expect(page).to have_content('BILLING ADDRESS')
          expect(page).to have_content(expected_address_format('BILLING ADDRESS', billing))
        end
      end

      # TODO: not passing because inline JS validation not working
      it 'sees form when new billing address invalid' do
        address = user.addresses.first
        billing = build(:address, address1: nil, state: state)
        find('label', text: 'Use Billing Address').click
        within("#shipping .select_address #shipping_address_#{address.id}") do
          find('label').click
        end
        within('#billing') do
          find('label', text: 'Other address').click
          fill_in_address(billing)
        end
        click_button 'Save and Continue'

        baddress1_message = page.find('#order_bill_address_attributes_address1').native.attribute('validationMessage')
        expect(baddress1_message).to eq('Please fill out this field.')

        within('#shipping') do
          expect(page).to have_checked_field(id: "order_ship_address_id_#{address.id}", visible: false)
        end
      end
    end

    describe 'entering address that is already saved', js: true do
      it 'does not save address for user' do
        expect do
          address = user.addresses.first
          find('label', text: 'Use Billing Address').click
          within("#shipping .select_address #shipping_address_#{address.id}") do
            find('label').click
          end
          within('#billing') do
            find('label', text: 'Other address').click
            fill_in_address(address)
          end
          complete_checkout(address)
        end.not_to change { user.addresses.count }
      end
    end
  end
end
