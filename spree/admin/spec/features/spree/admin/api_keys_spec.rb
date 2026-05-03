# frozen_string_literal: true

require 'spec_helper'

RSpec.feature 'API Keys', :js do
  stub_authorization!

  let!(:admin_user) { create(:admin_user) }

  before do
    allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(admin_user)
  end

  describe 'creating a secret API key' do
    before { visit spree.new_admin_api_key_path }

    it 'allows checking scope checkboxes and saves them' do
      fill_in 'api_key_name', with: 'My Integration'
      select 'Secret', from: 'api_key_key_type'

      check 'api_key_scopes_read_orders'
      check 'api_key_scopes_write_products'

      expect(page).to have_checked_field('api_key_scopes_read_orders', visible: :all)
      expect(page).to have_checked_field('api_key_scopes_write_products', visible: :all)

      within('#page-header') { click_button 'Create' }

      expect(page).not_to have_content('Scopes contains unknown scopes')
      expect(page).to have_content('Store this key securely')

      api_key = Spree::ApiKey.last
      expect(api_key.name).to eq('My Integration')
      expect(api_key.key_type).to eq('secret')
      expect(api_key.scopes).to contain_exactly('read_orders', 'write_products')
    end

    it 'renders scope checkboxes inside a form-checkbox container so they show checked state' do
      expect(page).to have_css('.custom-control.form-checkbox input#api_key_scopes_read_orders', visible: :all)
      expect(page).not_to have_css('.custom-control.custom-checkbox input#api_key_scopes_read_orders', visible: :all)
    end
  end
end
