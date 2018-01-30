require 'spec_helper'

describe 'Stores admin', type: :feature do
  stub_authorization!

  let!(:store) { create(:store) }

  describe 'visiting the stores page' do
    it 'should be on the stores page' do
      visit spree.admin_stores_path

      store_table = page.find('table')
      expect(store_table.all('tr').count).to eq 1
      expect(store_table).to have_content(store.name)
      expect(store_table).to have_content(store.url)
    end
  end

  describe 'creating store' do
    it 'should create store and associate it with the user' do
      visit spree.admin_stores_path

      click_link 'Add Store'
      page.fill_in 'store_name', with: 'Spree Example Test'
      page.fill_in 'store_url', with: 'test.localhost'
      page.fill_in 'store_mail_from_address', with: 'spree@example.com'
      page.fill_in 'store_code', with: 'SPR'
      click_button 'Create'

      expect(page.current_path).to eq spree.admin_stores_path
      store_table = page.find('table')
      expect(store_table.all('tr').count).to eq 2
      expect(Spree::Store.count).to eq 2
    end
  end

  describe 'updating store' do
    let(:updated_name) { 'New Store Name' }

    it 'should create store and associate it with the user' do
      visit spree.admin_stores_path

      click_link 'Edit'
      page.fill_in 'store_name', with: updated_name
      click_button 'Update'

      expect(page.current_path).to eq spree.admin_stores_path
      store_table = page.find('table')
      expect(store_table).to have_content(updated_name)
      expect(store.reload.name).to eq updated_name
    end
  end

  describe 'deleting store', js: true do
    let!(:second_store) { create(:store) }
    it 'should update store in lifetime stats' do
      visit spree.admin_stores_path

      spree_accept_alert do
        page.all('.icon-delete')[1].click
        wait_for_ajax
      end
      wait_for_ajax

      expect(Spree::Store.find_by_id(second_store.id)).to be_nil
    end
  end

  describe 'setting default store' do
    let!(:store1) { create(:store, default: false) }

    it 'should set a store as default' do
      visit spree.admin_stores_path
      click_button 'Set as default'

      expect(store.reload.default).to eq false
      expect(store1.reload.default).to eq true
    end
  end
end
