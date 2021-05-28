require 'spec_helper'

describe 'Stores admin', type: :feature, js: true do
  stub_authorization!

  let!(:store) { create(:store, checkout_zone_id: zone.id) }
  let!(:zone) { create(:zone, name: 'EU_VAT') }
  let!(:no_limits) { create(:zone, name: 'No Limits') }

  describe 'visiting the stores page' do
    before do
      I18n.backend.store_translations(:fr,
        spree: {
          i18n: {
            this_file_language: 'Français (FR)'
          }
        })
      store.update(
        name: 'My Store',
        url: 'example.com',
        supported_currencies: 'USD,EUR',
        default_locale: 'en',
        supported_locales: 'en,fr'
      )
    end

    it 'is on the stores page' do
      visit spree.admin_stores_path

      store_table = page.find('table')
      row_count = store_table.all(:css, 'tr').size
      expect(row_count).to eq 2
      expect(Spree::Store.count).to eq 1
      expect(store_table).to have_content('My Store')
      expect(store_table).to have_content('example.com')
      expect(store_table).to have_content('EUR, USD')
      expect(store_table).to have_content('English (US), Français (FR)')
    end
  end

  describe 'creating store' do
    context 'with checkout_zone set as preference in spree config file' do
      let!(:zone) { create(:zone, name: 'Asia') }

      before do
        store.update(checkout_zone_id: nil)
        Spree::Config[:checkout_zone] = 'Asia'
      end

      it 'sets default zone' do
        visit spree.admin_stores_path

        click_link 'New Store'

        expect(page).to have_current_path(spree.new_admin_store_path)
        expect(page).to have_selector(:id, 'select2-store_checkout_zone_id-container', text: 'Asia')
      end
    end

    context 'without checkout_zone set as preference in spree config file' do
      before do
        store.update(checkout_zone_id: nil)
        Spree::Config.preference_default(:checkout_zone)
      end

      it 'sets default zone' do
        visit spree.admin_stores_path

        click_link 'New Store'

        expect(page).to have_current_path(spree.new_admin_store_path)
        expect(page).to have_selector(:id, 'select2-store_checkout_zone_id-container', text: 'No Limits')
      end
    end

    it 'sets default currency value' do
      visit spree.admin_stores_path

      click_link 'New Store'

      expect(page).to have_current_path(spree.new_admin_store_path)
      expect(page).to have_selector(:id, 'select2-store_default_currency-container', text: 'United States Dollar (USD)')
    end

    it 'saving store' do
      visit spree.admin_stores_path

      click_link 'New Store'
      page.fill_in 'store_name', with: 'Spree Example Test'
      page.fill_in 'store_url', with: 'test.localhost'
      page.fill_in 'store_code', with: 'spree'
      page.fill_in 'store_mail_from_address', with: 'no-reply@example.com'
      page.fill_in 'store_customer_support_email', with: 'support@example.com'
      select2 'EUR', from: 'Default currency'
      select2_clear from: 'Supported Currencies'
      select2_search 'GBP', from: 'Supported Currencies'
      select2_select 'GBP', from: 'Supported Currencies'

      select2 'English (US)', from: 'Default locale'

      click_button 'Create'

      expect(page).to have_current_path spree.admin_stores_path
      expect(page).to have_content('successfully created!')

      row_count = page.all(:css, 'table tr').size
      expect(row_count).to eq 3
      expect(Spree::Store.count).to eq 2

      store = Spree::Store.last

      expect(store.default_currency).to eq 'EUR'
      expect(store.supported_currencies_list.map(&:iso_code)).to contain_exactly('EUR', 'GBP')
      expect(store.default_locale).to eq 'en'
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
      select2 new_currency, from: 'Default currency'
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

    describe 'uploading a favicon' do
      let(:favicon) { file_fixture('favicon.ico') }

      before do
        visit spree.admin_stores_path

        within_row(1) { click_icon :edit }
        attach_file('Favicon', favicon)

        click_on 'Update'
      end

      it 'allows uploading a favicon' do
        expect(page).to have_content('Store "Spree Test Store" has been successfully updated!')
        expect(store.reload.favicon_image.attached?).to be(true)
      end

      context 'when a favicon is invalid' do
        let(:favicon) { file_fixture('icon_512x512.png') }

        it 'prevents uploading a favicon and displays an error message' do
          expect(page).to have_content('Unable to update store.: Favicon image must be less than or equal to 256 x 256 pixel')
          expect(store.reload.favicon_image.attached?).to be(false) if Rails.version.to_f > 5.2
        end
      end
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
