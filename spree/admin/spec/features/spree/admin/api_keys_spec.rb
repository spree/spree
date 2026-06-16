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

    it 'allows checking scope checkboxes and saves them without an "unknown scopes" error' do
      # Scope checkboxes use the .form-checkbox style with the actual <input>
      # visually hidden; clicks must be routed through the associated <label>.
      expect(page).to have_css('.custom-control.form-checkbox input#api_key_scopes_read_orders', visible: :all)

      fill_in 'api_key_name', with: 'My Integration'
      select 'Secret', from: 'api_key_key_type'

      check 'read_orders', allow_label_click: true
      check 'write_products', allow_label_click: true

      expect(page).to have_checked_field('api_key_scopes_read_orders', visible: :all)
      expect(page).to have_checked_field('api_key_scopes_write_products', visible: :all)

      click_button 'Create'

      expect(page).not_to have_content('Scopes contains unknown scopes')

      api_key = Spree::ApiKey.last
      expect(api_key.name).to eq('My Integration')
      expect(api_key.key_type).to eq('secret')
      expect(api_key.scopes).to contain_exactly('read_orders', 'write_products')
    end
  end

  describe 'editing a secret API key' do
    let!(:api_key) do
      create(:api_key, :secret, store: @default_store, name: 'Integration', scopes: ['read_orders'])
    end

    before { visit spree.edit_admin_api_key_path(api_key) }

    it 'renames the key but shows scopes as read-only (no editable checkboxes)' do
      # Scopes are fixed for the life of a key — the edit form shows them as
      # static badges, not the create-time checkbox grid.
      expect(page).not_to have_css('input#api_key_scopes_read_orders', visible: :all)
      expect(page).to have_content('read_orders')

      fill_in 'api_key_name', with: 'Renamed Integration'
      # Two save buttons share the "Update" label (sticky header + form actions);
      # click the first to avoid an ambiguous match.
      first(:button, 'Update').click

      # Update is a Turbo Stream (no navigation) — wait for the persisted rename
      # to surface in the form before asserting on the record.
      expect(page).to have_field('api_key_name', with: 'Renamed Integration')

      api_key.reload
      expect(api_key.name).to eq('Renamed Integration')
      expect(api_key.scopes).to eq(['read_orders'])
    end
  end
end
