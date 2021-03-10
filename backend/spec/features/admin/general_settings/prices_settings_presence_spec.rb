require 'spec_helper'

describe 'Currencies settings presence', type: :feature, js: true do
  stub_authorization!

  context 'when accessing general settings page' do
    it 'Multi Currency settings are present' do
      visit spree.edit_admin_general_settings_path

      expect(page).to have_content 'Show Store selector'
    end
  end
end
