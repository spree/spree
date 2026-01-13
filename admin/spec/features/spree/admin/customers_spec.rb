require 'spec_helper'

RSpec.feature 'Customers', :js do
  stub_authorization!

  let!(:customer_user) { create(:user_with_addresses) }

  context 'email, names and location' do
    before { visit spree.admin_users_path }

    it 'displays them' do
      expect(page).to have_content(customer_user.first_name)
      expect(page).to have_content(customer_user.last_name)
      expect(page).to have_content(customer_user.billing_address.city)
      expect(page).to have_content(customer_user.billing_address.state_name_text)
      expect(page).to have_content(customer_user.email)
    end
  end

  context 'no. of orders and amount spent' do
    let!(:product) { create(:product_in_stock) }
    let!(:order) { create(:order, total: 10, user: customer_user, completed_at: 5.minutes.ago) }
    let!(:order2) { create(:order, total: 20, user: customer_user, completed_at: 5.minutes.ago) }
    let!(:order3) { create(:order, total: 30, user: customer_user, completed_at: 5.minutes.ago) }

    let!(:other_customer) { create(:user) }
    let!(:other_customer_order) { create(:order, total: 100, user: other_customer, completed_at: 5.minutes.ago) }
    let!(:other_customer_order2) { create(:order, total: 30, user: other_customer, completed_at: 5.minutes.ago) }

    before do
      visit spree.admin_users_path
    end

    it 'shows the correct number of orders and amount spend' do
      expect(page).to have_content('60.0')
      expect(page).to have_content('3')

      expect(page).to have_content('130.0')
      expect(page).to have_content('2')
    end
  end

  context 'without any addresses' do
    before do
      customer_user.billing_address.destroy!
      customer_user.shipping_address.destroy!

      visit spree.admin_user_path(customer_user)
    end

    scenario 'Admin adds a shipping address' do
      address_count = Spree::Address.count

      within('#user-ship-address') do
        click_on 'Add'

        fill_in 'First Name', with: 'John'
        fill_in 'Last Name', with: 'Doe'
        fill_in 'Address', with: '4 Lovely Street'
        fill_in 'City', with: 'Canton'
        fill_in 'Zip Code', with: '06019'

        click_button 'Create'
      end

      within('#user-ship-address') do
        expect(page).to have_content('John Doe')
        expect(page).to have_content('4 Lovely Street')
        expect(page).to have_content('Canton')
        expect(page).to have_content('06019')
      end

      expect(Spree::Address.count).to eq(address_count + 1)
      address = Spree::Address.last

      expect(customer_user.reload.ship_address_id).to eq(address.id)
      expect(customer_user.ship_address.address1).to eq('4 Lovely Street')
      expect(customer_user.ship_address.zipcode).to eq('06019')
      expect(customer_user.ship_address.city).to eq('Canton')
    end

    scenario 'Admin adds a billing address' do
      address_count = Spree::Address.count

      within('#user-bill-address') do
        click_on 'Add'

        fill_in 'First Name', with: 'John'
        fill_in 'Last Name', with: 'Doe'
        fill_in 'Address', with: '4 Lovely Street'
        fill_in 'City', with: 'Canton'
        fill_in 'Zip Code', with: '06019'

        click_button 'Create'
      end

      wait_for_turbo

      expect(Spree::Address.count).to eq(address_count + 1)
      address = Spree::Address.last

      expect(customer_user.reload.bill_address_id).to eq(address.id)
      expect(customer_user.bill_address.address1).to eq('4 Lovely Street')
      expect(customer_user.bill_address.zipcode).to eq('06019')
      expect(customer_user.bill_address.city).to eq('Canton')
    end
  end

  describe 'update' do
    let(:phone) { FFaker::PhoneNumber.phone_number }
    let(:ship_address) { create(:address, user: customer_user) }
    let(:bill_address) { create(:address, user: customer_user) }

    before do
      customer_user.update!(ship_address: ship_address, bill_address: bill_address)
      visit spree.admin_user_path(customer_user)
    end

    it 'can update user' do
      within '#user-details' do
        click_on 'Edit'
      end

      within '#drawer-dialog' do
        fill_in 'Phone', with: phone

        click_button 'Save'
      end

      wait_for_turbo

      within '#user-details' do
        expect(page).to have_content(phone)
      end
      expect(customer_user.reload.phone).to eq phone
    end

    it 'can update user ship address' do
      within('#user-ship-address') do
        click_on 'Edit'

        fill_in 'First Name', with: 'John'
        fill_in 'Last Name', with: 'Doe'

        click_button 'Update'
      end

      expect(page).to have_content('John Doe')
      expect(customer_user.reload.ship_address.first_name).to eq 'John'
      expect(customer_user.reload.ship_address.last_name).to eq 'Doe'
    end

    it 'can update user bill address' do
      within('#user-bill-address') do
        click_on 'Edit'

        scroll_to(find('#edit_address_billing'))

        fill_in 'First Name', with: 'John'
        fill_in 'Last Name', with: 'Doe'

        click_button 'Update'
      end

      expect(page).to have_content('John Doe')
      expect(customer_user.reload.bill_address.first_name).to eq 'John'
      expect(customer_user.reload.bill_address.last_name).to eq 'Doe'
    end

    scenario 'Admin uses the shipping address' do
      within('#user-bill-address') do
        click_on 'Edit'
        scroll_to(find('#edit_address_billing'))

        find('label', text: 'Use Shipping Address').click
      end

      wait_for_turbo

      within('#user-bill-address') do
        expect(page).to have_text('Same as shipping address')
      end
    end

    context 'when bill address is the same' do
      let(:bill_address) { ship_address }

      scenario 'Admin adds a new billing address' do
        within('#user-bill-address') do
          expect(page).to have_text('Same as shipping address')

          click_on 'Edit'
          click_on 'Add new address'

          fill_in 'First Name', with: 'John'
          fill_in 'Last Name', with: 'Doe'
          fill_in 'Address', with: '4 Lovely Street'
          fill_in 'City', with: 'Canton'
          fill_in 'Zip Code', with: '06019'

          click_button 'Create'
        end

        within('#user-bill-address') do
          expect(page).to have_content('John Doe')
          expect(page).to have_content('4 Lovely Street')
          expect(page).to have_content('Canton')
          expect(page).to have_content('06019')
        end

        expect(customer_user.reload.bill_address_id).not_to eq(bill_address.id)
        expect(customer_user.bill_address.address1).to eq('4 Lovely Street')
        expect(customer_user.bill_address.zipcode).to eq('06019')
        expect(customer_user.bill_address.city).to eq('Canton')
      end

      scenario 'Admin uses the shipping address' do
        address_count = Spree::Address.count

        within('#user-bill-address') do
          expect(page).to have_text('Same as shipping address')

          click_on 'Edit'
          find('label', text: 'Use Shipping Address').click
        end

        within('#user-bill-address') do
          expect(page).to have_text('Same as shipping address')
        end

        expect(Spree::Address.count).to eq(address_count)
        expect(customer_user.reload.bill_address_id).to eq(bill_address.id)
      end
    end

    context 'when user ship address is not editable' do
      let!(:order) { create(:completed_order_with_totals, user: customer_user, ship_address: ship_address, bill_address: bill_address) }

      before do
        ship_address.update!(first_name: 'Jane', last_name: 'Poe')
        order.reload
      end

      it 'creates a new one' do
        within('#user-ship-address') do
          click_on 'Edit'

          fill_in 'First Name', with: 'Janette'
          fill_in 'Last Name', with: 'Kovalsky'

          click_button 'Update'
        end

        expect(page).to have_content('Janette Kovalsky')

        wait_for_turbo

        expect(customer_user.reload.ship_address_id).not_to eq(ship_address.id)
        expect(customer_user.ship_address.first_name).to eq 'Janette'
        expect(customer_user.ship_address.last_name).to eq 'Kovalsky'

        expect(order.reload.ship_address_id).to eq(ship_address.id)
      end

      context 'when updating an existing ship address' do
        let!(:existing_address) do
          create(
            :address,
            user: customer_user,
            first_name: 'Janette',
            last_name: 'Kovalsky',
            address1: '100 California Street',
            address2: ship_address.address2,
            city: ship_address.city,
            zipcode: ship_address.zipcode,
            state: ship_address.state,
            country: ship_address.country,
            phone: ship_address.phone
          )
        end

        it 'switches the customer ship address to the existing address' do
          within('#user-ship-address') do
            click_on 'Edit'

            fill_in 'First Name', with: 'Janette'
            fill_in 'Last Name', with: 'Kovalsky'
            fill_in 'Address', with: '100 California Street'

            click_button 'Update'
          end

          expect(page).to have_content('100 California Street')

          expect(customer_user.reload.ship_address_id).to eq(existing_address.id)
          expect(order.reload.ship_address_id).to eq(ship_address.id)
        end
      end
    end

    context 'when user bill address is not editable' do
      let!(:order) { create(:completed_order_with_totals, user: customer_user, ship_address: ship_address, bill_address: bill_address) }

      before do
        bill_address.update!(first_name: 'Jane', last_name: 'Poe')
        order.reload
      end

      it 'creates a new one' do
        within('#user-bill-address') do
          click_on 'Edit'

          scroll_to(find('#edit_address_billing'))

          fill_in 'First Name', with: 'Gregory'
          fill_in 'Last Name', with: 'Moe'

          click_button 'Update'
        end

        expect(page).to have_content('Gregory Moe')

        wait_for_turbo

        expect(customer_user.reload.bill_address_id).not_to eq(bill_address.id)
        expect(customer_user.bill_address.first_name).to eq('Gregory')
        expect(customer_user.bill_address.last_name).to eq('Moe')

        expect(order.reload.bill_address_id).to eq(bill_address.id)
      end

      context 'when updating an existing bill address' do
        let!(:existing_address) do
          create(
            :address,
            user: customer_user,
            first_name: 'John',
            last_name: 'Doe',
            address1: '100 California Street',
            address2: bill_address.address2,
            city: bill_address.city,
            zipcode: bill_address.zipcode,
            state: bill_address.state,
            country: bill_address.country,
            phone: bill_address.phone
          )
        end

        it 'switches the customer bill address to the existing address' do
          within('#user-bill-address') do
            click_on 'Edit'

            scroll_to(find('#edit_address_billing'))

            fill_in 'First Name', with: 'John'
            fill_in 'Last Name', with: 'Doe'
            fill_in 'Address', with: '100 California Street'

            click_button 'Update'
          end

          expect(page).to have_content('100 California Street')

          expect(customer_user.reload.bill_address_id).to eq(existing_address.id)
          expect(order.reload.bill_address_id).to eq(bill_address.id)
        end
      end
    end
  end
end
