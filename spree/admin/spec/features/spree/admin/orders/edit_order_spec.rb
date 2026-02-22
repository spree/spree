require 'spec_helper'

describe 'Edit Order Spec', type: :feature do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let(:customer) { create(:user) }
  let(:admin_user) { create(:admin_user) }
  let!(:order) do
    create(
      :order,
       user: customer,
       ship_address: create(:address, user: customer),
       bill_address: create(:address, user: customer)
    )
  end

  before do
    visit spree.edit_admin_order_path(order)
  end

  describe 'order ready to ship', js: true do
    let!(:order) do
      create(:order_ready_to_ship, user: customer, ship_address: create(:address, user: customer), bill_address: create(:address, user: customer))
    end

    it 'can change shipping address' do
      within('#customer-edit-dropdown') do
        click_on 'dropdown-toggle'
        click_on Spree.t('admin.edit_shipping_address')
      end
      wait_for_dialog

      within('#main-dialog', visible: :all) do
        fill_in_address
        click_on 'Update', visible: false
      end

      # Wait for the page to show the success message after form submission completes
      expect(page).to have_content('successfully updated', wait: 10)
      expect(page).to have_content('John 99')
      expect(page).to have_content('Bethesda')

      expect(order.reload.ship_address.firstname).to eq('John 99')
      expect(order.ship_address.lastname).to eq('Doe')
      expect(order.ship_address.address1).to eq('100 first lane')
      expect(order.ship_address.address2).to eq('#101')
      expect(order.ship_address.city).to eq('Bethesda')
      expect(order.ship_address.zipcode).to eq('20170')
      expect(order.ship_address.country.name).to eq(store.default_country.name)
      expect(order.ship_address.state.name).to eq(store.default_country.states.first.name)
      expect(order.ship_address.phone).to eq('123-456-7890')
    end

    it 'can select existing shipping address' do
      address_to_select = order.user.addresses.first
      expect(order.ship_address).not_to eq(address_to_select)

      within('#customer-edit-dropdown') do
        click_on 'dropdown-toggle'
        click_on Spree.t('admin.edit_shipping_address')
      end
      wait_for_dialog

      within('#main-dialog', visible: :all) do
        select address_to_select.to_s.gsub('<br/>', ", "), from: 'shipping_address_id', visible: false
      end

      # Wait for the page to show the success message after auto-submit completes
      expect(page).to have_content('successfully updated', wait: 10)
      expect(page).to have_content(address_to_select.firstname)
      expect(page).to have_content(address_to_select.city)

      expect(order.reload.ship_address).to eq(address_to_select)
    end
  end

  context 'when order is not shipped', js: true do
    it 'can change shipping address' do
      within('#customer-edit-dropdown') do
        click_on 'dropdown-toggle'
        click_on Spree.t('admin.edit_shipping_address')
      end
      wait_for_dialog

      within('#main-dialog', visible: :all) do
        fill_in_address
        click_on 'Update', visible: false
      end

      # Wait for the page to show the success message after form submission completes
      expect(page).to have_content('successfully updated', wait: 10)
      expect(page).to have_content('John 99')
      expect(page).to have_content('Bethesda')

      expect(order.reload.ship_address.firstname).to eq('John 99')
      expect(order.ship_address.lastname).to eq('Doe')
      expect(order.ship_address.address1).to eq('100 first lane')
      expect(order.ship_address.address2).to eq('#101')
      expect(order.ship_address.city).to eq('Bethesda')
      expect(order.ship_address.zipcode).to eq('20170')
      expect(order.ship_address.country.name).to eq(store.default_country.name)
      expect(order.ship_address.state.name).to eq(store.default_country.states.first.name)
      expect(order.ship_address.phone).to eq('123-456-7890')
    end

    it 'can select existing shipping address' do
      address_to_select = order.user.addresses.first
      expect(order.ship_address).not_to eq(address_to_select)

      within('#customer-edit-dropdown') do
        click_on 'dropdown-toggle'
        click_on Spree.t('admin.edit_shipping_address')
      end
      wait_for_dialog

      within('#main-dialog', visible: :all) do
        select address_to_select.to_s.gsub('<br/>', ", "), from: 'shipping_address_id', visible: false
      end

      # Wait for the page to show the success message after auto-submit completes
      expect(page).to have_content('successfully updated', wait: 10)
      expect(page).to have_content(address_to_select.firstname)
      expect(page).to have_content(address_to_select.city)

      expect(order.reload.ship_address).to eq(address_to_select)
    end

    context 'when updating to an existing shipping address' do
      let!(:existing_address) do
        create(
          :address,
          user: customer,
          first_name: 'John 99',
          last_name: 'Doe',
          address1: '100 first lane',
          address2: '#101',
          city: 'Bethesda',
          zipcode: '20170',
          state: store.default_country.states.first,
          country: store.default_country,
          phone: '123-456-7890'
        )
      end

      it 'switches the shipping address to the existing address' do
        within('#customer-edit-dropdown') do
          click_on 'dropdown-toggle'
          click_on Spree.t('admin.edit_shipping_address')
        end
        wait_for_dialog

        within('#main-dialog', visible: :all) do
          fill_in_address
          click_on 'Update'
        end

        # Wait for the page to show the success message after form submission completes
        expect(page).to have_content('successfully updated', wait: 10)
        expect(page).to have_content('John 99')
        expect(page).to have_content('Bethesda')

        expect(order.reload.ship_address).to eq(existing_address)
      end
    end
  end

  def fill_in_address
    # Use visible: false for form fields inside dialogs in headless Chrome
    fill_in 'address_firstname',       with: 'John 99', visible: false
    fill_in 'address_lastname',        with: 'Doe', visible: false
    fill_in 'address_address1',        with: '', visible: false
    fill_in 'address_address1',        with: '100 first lane', visible: false
    fill_in 'address_address2',        with: '', visible: false
    fill_in 'address_address2',        with: '#101', visible: false
    select store.default_country.name, from: 'address_country_id', visible: false if store.countries_available_for_checkout.count > 1
    fill_in 'address_city',            with: 'Bethesda', visible: false
    fill_in 'address_zipcode',         with: '20170', visible: false
    select store.default_country.states.first.name, from: 'address_state_id', visible: false
    fill_in 'address_phone', with: '123-456-7890', visible: false
  end
end
