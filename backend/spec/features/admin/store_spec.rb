require 'spec_helper'

describe 'Stores', type: :feature, js: true do
  stub_authorization!

  context 'creating new store' do
    before do
      visit spree.admin_path

      click_link 'Configurations'
      click_link 'Stores'
      click_link 'New Store'
    end

    it 'has required fields' do
      expect(page).to have_field(id: 'store_name')
      expect(page).to have_field(id: 'store_code')
      expect(page).to have_field(id: 'store_url')
      expect(page).to have_field(id: 'store_mail_from_address')
    end

    it 'has footer info fields' do
      expect(page).to have_field(id: 'store_description')
      expect(page).to have_field(id: 'store_address')
      expect(page).to have_field(id: 'store_contact_phone')
      expect(page).to have_field(id: 'store_contact_email')
    end

    it 'creates a new store' do
      fill_in 'Name', with: 'Store name'
      fill_in 'Code', with: 'example_store'
      fill_in 'URL', with: 'store.example.com'
      fill_in 'Mail from address', with: 'store@example.com'

      click_button 'Create'

      expect(page).to have_content('successfully created!')
    end

    it 'creates a new store with footer info' do
      fill_in 'Name', with: 'Store name'
      fill_in 'Code', with: 'example_store'
      fill_in 'URL', with: 'store.example.com'
      fill_in 'Mail from address', with: 'store@example.com'
      fill_in 'Description', with: 'New store description'
      fill_in 'Address', with: 'New store address 123, City 123'
      fill_in 'Contact phone', with: '123123123'
      fill_in 'Contact email', with: 'contact@example.com'

      click_button 'Create'

      expect(page).to have_content('successfully created!')
    end
  end

  context 'editing existing store' do
    before do
      create(:store, name: 'Some existing store')

      visit spree.admin_path

      click_link 'Configurations'
      click_link 'Stores'
    end

    it 'edits existing store' do
      within_row(1) { click_icon :edit }
      fill_in 'Mail from address', with: 'new_email@example.com'
      click_button 'Update'

      expect(page).to have_content('successfully updated!')
    end

    it 'edits existing stores footer info' do
      within_row(1) { click_icon :edit }
      fill_in 'Description', with: 'Some edited description'
      click_button 'Update'

      expect(page).to have_content('successfully updated!')
    end
  end
end
