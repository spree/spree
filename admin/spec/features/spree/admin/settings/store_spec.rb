require 'spec_helper'

describe 'Store admin', type: :feature, js: true do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let!(:admin_user) { create(:admin_user) }
  let!(:zone) { create(:zone, name: 'EU_VAT') }

  before do
    allow(Spree).to receive(:root_domain).and_return('lvh.me')
    allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(admin_user)

    # Allow new store subdomain hosts for testing
    Rails.application.config.hosts << 'new-store.lvh.me'
    Rails.application.config.hosts << /.*\.lvh\.me/
  end

  describe 'creating another store' do
    it 'creates another store' do
      visit spree.admin_root_path
      find('#store-menu .dropdown:last-child button').click
      click_on 'New Store'

      expect(page).to have_content('New Store')
      fill_in 'store_name', with: 'New Store Name'
      click_button 'Create'

      expect(page).to have_content('Getting started')

      new_store = Spree::Store.last

      expect(page).to have_current_path(spree.admin_getting_started_url(host: new_store.url, port: Capybara.current_session.server.port))
    end
  end

  describe 'updating store' do
    it 'updates store' do
      visit spree.edit_admin_store_path(section: 'general-settings')
      page.fill_in 'store_name', with: '', wait: 5
      page.fill_in 'store_name', with: 'New Store Name', wait: 5
      within('#page-header') { click_button 'Update' }

      expect(page).to have_content('successfully updated')

      # tom_select 'EUR', from: 'Currency'
      # within('#page-header') { click_button 'Update' }

      wait_for_turbo

      expect(page).to have_content('successfully updated')

      # expect(store.reload.default_currency).to eq 'EUR'
      expect(store.reload.name).to eq 'New Store Name'
      # expect(store.checkout_zone).to eq zone
      # expect(store.url).to eq 'www.my-store.com/shop'
    end

    it 'have unit system and weightage unit' do
      visit spree.edit_admin_store_path(section: 'general-settings')

      expect(page).to have_select(
        'store_preferred_unit_system',
        selected: 'Imperial system'
      )

      expect(page).to have_select(
        'store_preferred_weight_unit',
        selected: ['Pound (lb)']
      )

      select 'Imperial system', from: 'store_preferred_unit_system'
      within('#page-header') { click_button 'Update' }

      expect(page).to have_content('successfully updated')

      store.reload
      expect(store.preferred_weight_unit).to eq 'lb'
    end
  end
end
