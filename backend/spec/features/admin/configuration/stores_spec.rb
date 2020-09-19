require 'spec_helper'

describe 'Stores admin', type: :feature, js: true do
  stub_authorization!

  let!(:store) { create(:store) }

  describe 'visiting the stores page' do
    it 'is on the stores page' do
      visit spree.admin_stores_path

      store_table = page.find('table')
      row_count = store_table.all(:css, 'tr').size
      expect(row_count).to eq 2
      expect(Spree::Store.count).to eq 1
      expect(store_table).to have_content(store.name)
      expect(store_table).to have_content(store.url)
    end
  end

  describe 'creating store' do
    it 'sets default currency value' do
      visit spree.admin_stores_path

      click_link 'New Store'

      expect(page).to have_current_path(spree.new_admin_store_path)
      expect(page).to have_selector(:id, 's2id_store_default_currency', text: 'United States Dollar (USD)')
    end

    it 'saving store' do
      visit spree.admin_stores_path

      click_link 'New Store'
      page.fill_in 'store_name', with: 'Spree Example Test'
      page.fill_in 'store_url', with: 'test.localhost'
      page.fill_in 'store_code', with: 'spree'
      page.fill_in 'store_mail_from_address', with: 'no-reply@example.com'
      page.fill_in 'store_customer_support_email', with: 'support@example.com'
      select2 'EUR', from: 'Currency'
      click_button 'Create'

      expect(page).to have_current_path spree.admin_stores_path

      row_count = page.all(:css, 'table tr').size
      expect(row_count).to eq 3
      expect(Spree::Store.count).to eq 2
    end
  end

  describe 'updating store' do
    let(:updated_name) { 'New Store Name' }
    let(:new_currency) { 'EUR' }

    it do
      visit spree.admin_stores_path

      within_row(1) do
        click_icon :edit
      end
      page.fill_in 'store_name', with: updated_name
      select2 new_currency, from: 'Currency'
      click_button 'Update'

      expect(page).to have_current_path spree.admin_stores_path
      store_table = page.find('table')
      expect(store_table).to have_content(updated_name)
      expect(store_table).to have_content(new_currency)
      store.reload
      expect(store.name).to eq updated_name
      expect(store.default_currency).to eq new_currency
    end

    it 'lets me enable new order notifications by setting a notification email address' do
      store_owner_email = 'new-order-notifications@example.com'
      visit spree.admin_stores_path

      within_row(1) do
        click_icon :edit
      end
      page.fill_in 'store_new_order_notifications_email', with: store_owner_email
      click_button 'Update'

      store.reload
      expect(store.new_order_notifications_email).to eq(store_owner_email)
    end
  end

  describe 'deleting store' do
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
      within_row(2) do
        click_icon :save
      end

      expect(store.reload.default).to eq false
      expect(store1.reload.default).to eq true
    end
  end
end
