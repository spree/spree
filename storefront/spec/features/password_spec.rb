require 'spec_helper'

RSpec.describe 'Password page', type: :feature do
  context 'when storefront is password protected' do
    let(:store) { Spree::Store.default }

    before do
      store.preferred_password_protected = true
      store.storefront_password = 'password'
      store.save!
    end

    it 'redirects to password page' do
      visit spree.root_path
      expect(page).to have_current_path(spree.password_path)
    end

    it 'allows user to provide password and access the store' do
      visit spree.password_path
      click_on 'Enter using password'
      fill_in 'password', with: 'password'
      click_button 'Enter'
      expect(page).to have_current_path(spree.root_path)
    end
  end
end
