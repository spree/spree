require 'spec_helper'

describe 'Updating currencies settings', type: :feature, js: true do
  let!(:store) { create(:store, default: true) }
  stub_authorization!

  describe 'clearing cache' do
    it 'returns flash alert of type success' do
      visit spree.edit_admin_general_settings_path

      click_button 'Clear Cache'
      page.accept_alert

      assert_admin_flash_alert_success('Cache was flushed.')
    end
  end
end
