require 'spec_helper'

describe 'Store', type: :feature do
  context 'stores footer info is shown in footer', js: true do
    before do
      create(:store, default: true, description: 'This is store description', address: 'Address street 123, City 123', contact_phone: '123123123', customer_support_email: 'store@example.com')

      visit spree.root_path
    end

    it 'shows stores footer info in page footer' do
      within '#footer' do
        expect(page).to have_content('This is store description')
        expect(page).to have_content('Address street 123, City 123')
        expect(page).to have_content('123123123')
        expect(page).to have_content('store@example.com')
      end
    end
  end

  context 'store switchinng based on url' do
    let!(:store) { Spree::Store.default }
    let!(:another_store) { create(:store, url: 'another-store.lvh.me', name: 'Another Store') }

    context 'existing store found' do
      before do
        Capybara.app_host = 'http://another-store.lvh.me'
        visit spree.root_path
      end

      after { Capybara.app_host = nil }

      it { expect(page).to have_content(another_store.name) }
    end

    context 'non-existing store fallbacks to the default store' do
      before do
        Capybara.app_host = 'http://wrong-store.lvh.me'
        visit spree.root_path
      end

      after { Capybara.app_host = nil }

      it { expect(page).to have_content(store.name) }
    end
  end
end
