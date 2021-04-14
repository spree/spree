require 'spec_helper'

describe 'Updating currencies settings', type: :feature, js: true do
  let!(:store) { create(:store, default: true) }
  stub_authorization!

  describe 'enabling currency settings' do
    before do
      reset_spree_preferences do |config|
        config.show_store_selector = false
      end
    end

    it 'allows to enable currency settings' do
      visit spree.edit_admin_general_settings_path

      # Test initial state
      expect(page).to have_unchecked_field('show_store_selector')

      # Interact with the form
      check('show_store_selector')
      click_button 'Update'

      # Test final state
      expect(page).to have_content 'General Settings has been successfully updated!'
      expect(page).to have_checked_field('show_store_selector')
      assert_admin_flash_alert_success('General Settings has been successfully updated!')
    end
  end

  describe 'disabling currency settings' do
    before do
      reset_spree_preferences do |config|
        config.show_store_selector = true
      end
    end

    it 'allows to disable currency settings' do
      visit spree.edit_admin_general_settings_path

      expect(page).to have_checked_field('show_store_selector')

      uncheck('show_store_selector')
      click_button 'Update'

      expect(page).to have_content 'General Settings has been successfully updated!'
      expect(page).to have_unchecked_field('show_store_selector')
    end
  end

  describe 'clearing cache' do
    it 'returns flash alert of type success' do
      visit spree.edit_admin_general_settings_path

      click_button 'Clear Cache'
      page.accept_alert

      assert_admin_flash_alert_success('Cache was flushed.')
    end
  end
end
