require 'spec_helper'

describe 'Store', type: :feature, js: true do
  context 'stores footer info is shown in footer' do
    before do
      create(:store, default: true, description: 'This is store description', address: 'Address street 123, City 123', contact_phone: '123123123', contact_email: 'store@example.com')

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
end
