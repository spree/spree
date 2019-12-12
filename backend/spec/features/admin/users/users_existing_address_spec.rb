require 'spec_helper'

describe 'Users Exisitng Address', type: :feature, js: true do
  stub_authorization!

  let!(:user_a) { create(:user, email: 'a@example.com') }
  let!(:user_b) { create(:user, email: 'b@example.com') }
  let!(:address) { create(:address, user: user_b) }

  context 'is not displayed' do
    before do
      visit spree.edit_admin_user_path(user_a)
      click_link 'Addresses'
    end

    it 'when user has no existing addresses' do
      expect(user_a.addresses.count).to eq 0
      expect(page).not_to have_content Spree.t('existing_addresses', address_name: 'Billing')
      expect(page).not_to have_content Spree.t('existing_addresses', address_name: 'Shipping')
    end
  end

  context 'is displayed' do
    before do
      visit spree.edit_admin_user_path(user_b)
      click_link 'Addresses'
    end

    it 'when user has an existing address' do
      expect(user_b.addresses.count).to eq 1
      expect(page).to have_content Spree.t('existing_addresses', address_name: 'Billing')
      expect(page).to have_content Spree.t('existing_addresses', address_name: 'Shipping')
    end
  end

  context 'can be edited' do
    before do
      visit spree.edit_admin_user_path(user_b)
      click_link 'Addresses'

      within '#bill_address' do
        click_link 'Edit'
      end
    end

    it 'returns success and redirects users address' do
      expect(page).to have_current_path(spree.edit_admin_address_path(address))

      fill_in_address
      click_button 'Update'

      expect(user_b.addresses.count).to eq 1
      expect(page).to have_css('#bill_address', text: 'John 99')
      expect(page).to have_current_path(spree.addresses_admin_user_path(user_b))
      expect(page).to have_content Spree.t(:successfully_updated, resource: Spree.t(:address))
    end
  end

  def fill_in_address
    fill_in 'First Name', with: 'John 99'
    fill_in 'Last Name',  with: 'Doe'
    fill_in 'Address',    with: '100 first lane'
    fill_in 'City',       with: 'Bethesda'
    fill_in 'Zip Code',   with: '20170'
    fill_in 'Phone',      with: '123-456-7890'
  end
end
