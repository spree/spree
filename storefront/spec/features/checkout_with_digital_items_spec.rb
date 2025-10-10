require 'spec_helper'

describe 'Checkout with digital items', js: true do
  let(:order) { create(:order, user_id: nil, store: store) }
  let!(:digital_shipping_method) { create(:digital_shipping_method) }
  let!(:check_payment_method) { create(:check_payment_method, stores: [store], display_on: :both) }
  let(:store) { Spree::Store.default }
  let(:country) { store.default_country }
  let!(:state) { country.states.find_by(name: 'New York') || create(:state, country: country, name: 'New York', abbr: 'NY') }

  context 'with only digital items' do
    let(:digital_product) { create(:digital_product, stores: [store]) }
    let(:digital_variant) { digital_product.master }
    let(:order) { create(:order, user_id: nil, store: store) }

    before do
      Spree::Cart::AddItem.call(order: order, variant: digital_variant, quantity: 1)
      order.reload
    end

    it 'skips shipping address form and delivery step' do
      visit "/checkout/#{order.token}"

      # Should not show shipping address form
      expect(page).not_to have_content('Shipping Address')
      expect(page).not_to have_field('First Name')
      expect(page).not_to have_field('Last Name')
      expect(page).not_to have_field('Address')

      fill_in 'Email', with: 'guest@mail.com'
      click_on 'Save and Continue'

      # Should show billing address form
      expect(page).to have_content('Billing Address')

      fill_in 'order_bill_address_attributes_firstname', with: 'Guest'
      fill_in 'order_bill_address_attributes_lastname', with: 'User'
      fill_in 'order_bill_address_attributes_address1', with: '123 Main St'
      fill_in 'order_bill_address_attributes_city', with: 'New York'
      fill_in 'order_bill_address_attributes_zipcode', with: '10001'
      select 'United States of America', from: 'order_bill_address_attributes_country_id'
      select 'New York', from: 'order_bill_address_attributes_state_id'
      fill_in 'order_bill_address_attributes_phone', with: '555-123-4567'

      click_on 'Pay'

      expect(page).to have_content("Thanks Guest for your order!")
      expect(page).to have_content("Order #{order.number}")
      expect(page).to have_content(digital_product.name)
      expect(page).to have_content('Check')

      expect(order.reload.state).to eq('complete')
    end

    context 'for a signed in user with addresses' do
      let(:user) { create(:user_with_addresses) }
      let(:order) { create(:order, user: user, store: store) }

      before do
        login_as(user)
        Spree::Cart::AddItem.call(order: order, variant: digital_variant, quantity: 1)
        order.reload
      end

      it 'address book and delivery step' do
        visit "/checkout/#{order.token}"

        # Should not show shipping address form
        expect(page).not_to have_content('Shipping Address')
        expect(page).not_to have_field('First Name')

        click_on 'Save and Continue'

        expect(page).to have_content('Billing Address')

        click_on 'Pay'

        expect(page).to have_content("Thanks #{user.bill_address.first_name} for your order!")
        expect(page).to have_content("Order #{order.number}")
        expect(page).to have_content(digital_product.name)
        expect(page).to have_content('Check')

        expect(order.reload.state).to eq('complete')
        expect(order.ship_address).to be_nil
      end
    end
  end
end
