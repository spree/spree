require 'spec_helper'

describe 'Accounts section on storefront', type: :feature do
  describe 'Edit Profile' do
    let(:user) { create(:user) }
    let(:first_name) { FFaker::Name.first_name }
    let(:last_name) { FFaker::Name.last_name }
    let(:phone) { FFaker::PhoneNumber.phone_number }

    before do
      login_as(user, scope: :user)
      visit '/account/profile/edit'
    end

    it 'can edit profile' do
      fill_in 'First Name', with: first_name
      fill_in 'Last Name', with: last_name
      fill_in 'Phone', with: phone

      click_on 'Update'

      expect(page).to have_content 'Account has been successfully updated'

      user.reload

      expect(user.first_name).to eq(first_name)
      expect(user.last_name).to eq(last_name)
      expect(user.phone).to eq(phone)
    end
  end

  describe 'recent orders' do
    let(:user) { create(:user_with_addresses) }
    let(:order1) { create(:shipped_order, user: user) }
    let(:order2) { create(:shipped_order, user: user) }

    before do
      order1.update(completed_at: 1.day.ago)
      order2.update(completed_at: 1.day.ago)
      order2.shipments.first.update(address: user.ship_address)

      login_as(user, scope: :user)
      visit '/account'
    end

    it 'shows orders information' do
      expect(page).to have_content(order1.number)
      expect(page).to have_content(order2.number)
    end

    it 'redirects to order page' do
      click_on order2.number
      expect(page).to have_content('Delivery Address')
      expect(page).to have_content(user.ship_address.city)
      expect(page).to have_content('Billing Address')
      expect(page).to have_content(user.bill_address.city)
      expect(page).to have_content(order2.products.first.name)
      expect(page).to have_content('Payment Information')
      expect(page).to_not have_link('Return or replace')
    end
  end

  describe 'order page' do
    let(:user) { create(:user_with_addresses) }
    let(:order) { create(:shipped_order, user: user) }

    before { login_as(user, scope: :user) }

    context 'when shipment is shipped' do
      before do
        order.shipments.first.shipping_method.update!(tracking_url: 'https://example.com')
        visit "/account/orders/#{order.number}"
      end

      it do
        expect(page).not_to have_content('You will receive a refund in the next few days.')
        expect(page).not_to have_content('No tracking details provided')
        expect(page).to have_link Spree.t(:track_items)
      end
    end

    context 'when shipment is pending' do
      let(:order) { create(:order_ready_to_ship, user: user) }

      before do
        visit "/account/orders/#{order.number}"
      end

      it do
        expect(page).not_to have_content('You will receive a refund in the next few days.')
        expect(page).to have_content('No tracking details provided.')
        expect(page).to have_button Spree.t(:track_items), disabled: true
      end
    end
  end

  describe 'Addresses' do
    let(:addresses) { create_pair(:address) }
    let(:user) { create(:user, addresses: addresses) }

    before do
      login_as(user, scope: :user)
      visit spree.account_addresses_path
    end

    describe 'list' do
      it 'shows addresses information' do
        expect(page).to have_content(addresses.first.address1)
        expect(page).to have_content(addresses.second.address1)
      end
    end

    describe 'edit', js: true do
      it 'saves address' do
        address = user.addresses.first
        within("#address_#{address.id}") do
          click_on 'Edit'
        end
        wait_for_turbo

        expect(page).to have_content('Edit Address', wait: 5.seconds)

        fill_in 'address_firstname', with: 'Firstname'
        fill_in 'address_lastname', with: 'Lastname'
        fill_in 'address_city', with: 'Skopje'
        fill_in 'address_address1', with: 'Street 122'
        click_on Spree.t(:update)
        expect(page).to have_content('Firstname Lastname')

        address.reload
        expect(address.address1).to eq('Street 122')
        expect(address.firstname).to eq('Firstname')
        expect(address.lastname).to eq('Lastname')
        expect(address.city).to eq('Skopje')
      end
    end

    describe 'adding address' do
      let(:user) { create(:user, addresses: [], phone: '+1 1234567890') }
      let(:state) { create(:state, country: Spree::Store.default.default_country) }

      before do
        state
        login_as(user, scope: :user)
        visit '/account/addresses'
      end

      it 'creates an address', js: true do
        click_on Spree.t(:add)
        fill_in_address_form
        find('[data-test-id="add-address-button"]').click
        wait_for_turbo

        expect(page).to have_content('successfully created')
        expect(page).to have_content('Firstname Lastname')
        expect(page).to have_content('Street 122')
        expect(page).to have_content('Skopje')
        expect(page).to have_content('00007')

        expect(user.addresses.reload.count).to eq(1)

        address = user.addresses.first
        expect(address.firstname).to eq('Firstname')
        expect(address.lastname).to eq('Lastname')
        expect(address.address1).to eq('Street')
        expect(address.address2).to eq('122')
        expect(address.city).to eq('Skopje')
        expect(address.zipcode).to eq('00007')
      end

      context 'when user has phone number', js: true do
        it 'phone field should be prefilled' do
          click_on Spree.t(:add)
          expect(page).to have_field('address_phone', with: user.phone)
        end

        it 'changing address phone should not change user phone' do
          expect do
            click_on Spree.t(:add)
            fill_in_address_form
            find('[data-test-id="add-address-button"]').click
            wait_for_turbo
          end.not_to change { user.phone }
        end
      end

      context 'when user does not have phone number' do
        before do
          user.update(phone: nil)
        end

        it 'should set address phone to user phone', js: true do
          click_on Spree.t(:add)
          expect(page).to have_field('address_phone', text: '')
          fill_in_address_form
          find('[data-test-id="add-address-button"]').click
          wait_for_turbo

          expect(user.addresses.reload.count).to eq(1)

          expect(user.reload.phone).to eq('77777777')
        end
      end

      def fill_in_address_form
        fill_in 'address_firstname', with: 'Firstname'
        fill_in 'address_lastname', with: 'Lastname'
        fill_in 'address_city', with: 'Skopje'
        fill_in 'address_address1', with: 'Street'
        fill_in 'address_address2', with: '122'
        fill_in 'address_zipcode', with: '00007'
        fill_in 'address_phone', with: '77777777'
      end
    end

    describe 'destroy' do
      let(:user) { create(:user_with_addresses) }

      before do
        login_as(user, scope: :user)
        visit spree.account_addresses_path
      end

      it 'destroys the address', js: true do
        expect(user.addresses.count).to eq(2)
        click_on :delete_address, match: :first
        click_on :confirm_delete_address
        wait_for_turbo
        expect(page).to have_content('successfully removed')
        expect(user.addresses.count).to eq(1)
      end
    end
  end

  describe 'newsletter' do
    let(:user) { create(:user, accepts_email_marketing: accepts_email_marketing) }

    before do
      login_as(user, scope: :user)
      visit spree.edit_account_newsletter_path
    end

    context 'when user is already subscribed' do
      let(:accepts_email_marketing) { true }

      it 'unsubscribes from the newsletter' do
        expect(page).to have_content(Spree.t('storefront.newsletter_subscription.status', status: Spree.t(:subscribed)))
        click_on 'unsubscribe'
        wait_for_turbo

        expect(page).to have_content(Spree.t('storefront.newsletter_subscription.status', status: Spree.t(:not_subscribed)))
        expect(user.reload.accepts_email_marketing).to be false
      end
    end

    context 'when user is not subscribed' do
      let(:accepts_email_marketing) { false }

      it 'subscribes to the newsletter' do
        expect(page).to have_content(Spree.t('storefront.newsletter_subscription.status', status: Spree.t(:not_subscribed)))
        click_on 'subscribe'
        wait_for_turbo

        expect(page).to have_content(Spree.t('storefront.newsletter_subscription.status', status: Spree.t(:subscribed)))
        expect(user.reload.accepts_email_marketing).to be true
      end
    end
  end
end
