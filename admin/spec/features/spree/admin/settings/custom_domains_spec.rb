require 'spec_helper'

describe 'Custom domains admin', type: :feature do
  stub_authorization!
  let(:store) { Spree::Store.default }

  context 'without custom domains' do
    it 'can change store code' do
      visit spree.admin_custom_domains_path

      fill_in 'store[code]', with: 'new-code'
      click_on 'Update'

      expect(page).to have_field('store[code]', with: 'new-code')
      expect(page.current_url).to include('new-code')
    end
  end

  context 'with custom domains' do
    let!(:custom_domain) { create(:custom_domain, store: store) }

    it 'cannot change store code' do
      visit spree.admin_custom_domains_path

      expect(page).to have_field('store[code]', with: store.code, disabled: true)
    end

    it 'can manage custom domains' do
      visit spree.admin_custom_domains_path

      expect(page).to have_link('New domain')

      within_row(1) do
        expect(page).to have_content(custom_domain.url)
      end
    end
  end
end
