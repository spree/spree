require 'spec_helper'

describe 'Payment Methods', type: :feature do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let!(:store_1) { create(:store) }
  let!(:store_2) { create(:store) }
  let!(:store_3) { create(:store, url: 'another-store.lvh.me') }

  let!(:payment_method_one) { create(:payment_method, stores: [store]) }
  let!(:payment_method_two) { create(:payment_method, name: 'Should Be MIA', stores: [store_3]) }

  before do
    visit spree.admin_payment_methods_path
  end

  context 'managine payment methods by store' do
    it 'only displays payment methods for current store' do
      within('table#listing_payment_methods') do
        expect(page).to have_content(payment_method_one.name)
        expect(page).not_to have_content(payment_method_two.name)

        Capybara.app_host = 'http://another-store.lvh.me'

        visit spree.admin_payment_methods_path

        expect(page).not_to have_content(payment_method_one.name)
        expect(page).to have_content(payment_method_two.name)

        Capybara.app_host = nil
      end
    end
  end

  context 'admin visiting payment methods listing page' do
    it 'displays existing payment methods' do
      create(:check_payment_method)
      refresh

      within('table#listing_payment_methods') do
        expect(all('th')[1].text).to eq('Name')
        expect(all('th')[2].text).to eq('Provider')
        expect(all('th')[3].text).to eq('Display')
        expect(all('th')[4].text).to eq('Active')
      end

      within('table#listing_payment_methods') do
        expect(page).to have_content('Check')
      end
    end
  end

  context 'admin creating a new payment method', js: true do
    it 'is able to create a new payment method' do
      within find('#contentHeader') do
        click_link 'admin_new_payment_methods_link'
      end

      expect(page).to have_content('New Payment Method')
      fill_in 'payment_method_name', with: 'check90'
      fill_in 'payment_method_description', with: 'check90 desc'
      select 'PaymentMethod::Check', from: 'gtwy-type'
      click_button 'Create'
      expect(page).to have_content('successfully created!')

      expect(page).to have_select('payment_method_store_ids', selected: store.unique_name)
    end
  end

  context 'admin editing a payment method', js: true do
    before do
      visit spree.edit_admin_payment_method_path(check_payment_method)
    end

    let!(:check_payment_method) { create(:check_payment_method, name: 'Check') }

    it 'is able to edit an existing payment method' do
      fill_in 'payment_method_name', with: 'Payment 99'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')
      expect(page).to have_field('payment_method_name', with: 'Payment 99')

      expect(check_payment_method.reload.stores).to contain_exactly(store)
    end

    it 'is able to associate payment method with 2 stores' do
      expect(page).to have_content('Check')

      select2_open label: 'Stores'
      select2_search store_1.unique_name, from: 'Stores'
      select2_select store_1.unique_name, from: 'Stores', match: :first

      select2_open label: 'Stores'
      select2_search store_3.unique_name, from: 'Stores'
      select2_select store_3.unique_name, from: 'Stores', match: :first

      click_button 'Update'
      expect(page).to have_content('successfully updated!')

      expect(check_payment_method.reload.stores).to contain_exactly(store, store_1, store_3)
    end

    it 'displays validation errors' do
      fill_in 'payment_method_name', with: ''
      click_button 'Update'
      expect(page).to have_content("Name can't be blank")
    end
  end
end
