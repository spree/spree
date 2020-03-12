require 'spec_helper'

describe 'General Settings', type: :feature do
  stub_authorization!

  before do
    create(:store, name: 'Test Store', url: 'test.example.com', mail_from_address: 'test@example.com')
    visit spree.edit_admin_general_settings_path
  end

  context 'clearing the cache', js: true do
    it 'clears the cache' do
      expect(page).not_to have_content(Spree.t(:clear_cache_ok))
      visit spree.edit_admin_general_settings_path
      expect(page).not_to have_content(Spree.t(:clear_cache_ok))
      expect(page).to have_content(Spree.t(:clear_cache_warning))

      page.accept_confirm do
        click_button 'Clear Cache'
      end

      expect(page).to have_content(Spree.t(:clear_cache_ok))
    end
  end
end
