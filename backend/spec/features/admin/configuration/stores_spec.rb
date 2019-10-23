require 'spec_helper'

describe 'Stores admin', type: :feature do
  stub_authorization!

  let!(:store) { create(:store) }

  describe 'visiting the stores page' do
    it 'is on the stores page' do
      visit spree.admin_stores_path

      store_table = page.find('table')
      expect(store_table).to have_css('tr').once
      expect(store_table).to have_content(store.name)
      expect(store_table).to have_content(store.url)
    end
  end

  describe 'creating store' do
    it 'sets default currency value' do
      visit spree.admin_stores_path

      click_link 'New Store'

      expect(page).to have_selector("input[value='USD']")
    end

    it 'saving store' do
      visit spree.admin_stores_path

      click_link 'New Store'
      page.fill_in 'store_name', with: 'Spree Example Test'
      page.fill_in 'store_url', with: 'test.localhost'
      page.fill_in 'store_mail_from_address', with: 'spree@example.com'
      page.fill_in 'store_code', with: 'SPR'
      page.fill_in 'store_default_currency', with: 'EUR'
      click_button 'Create'

      expect(page).to have_current_path spree.admin_stores_path
      store_table = page.find('table')
      expect(store_table).to have_css('tr').twice
      expect(Spree::Store.count).to eq 2
    end
  end

  describe 'updating store' do
    let(:updated_name) { 'New Store Name' }
    let(:new_currency) { 'EUR' }

    it do
      visit spree.admin_stores_path

      click_link 'Edit'
      page.fill_in 'store_name', with: updated_name
      page.fill_in 'store_default_currency', with: new_currency
      click_button 'Update'

      expect(page).to have_current_path spree.admin_stores_path
      store_table = page.find('table')
      expect(store_table).to have_content(updated_name)
      expect(store_table).to have_content(new_currency)
      expect(store.reload.name).to eq updated_name
    end
  end

  describe 'deleting store', js: true do
    let!(:second_store) { create(:store) }

    it 'updates store in lifetime stats' do
      visit spree.admin_stores_path

      accept_confirm do
        page.all('.icon-delete', minimum: 2)[1].click
      end
      expect(page).to have_content('has been successfully removed!')

      expect(Spree::Store.find_by_id(second_store.id)).to be_nil
    end
  end

  describe 'setting default store' do
    let!(:store1) { create(:store, default: false) }

    it 'sets a store as default' do
      visit spree.admin_stores_path
      click_button 'Set as default'

      expect(store.reload.default).to eq false
      expect(store1.reload.default).to eq true
    end
  end
end
