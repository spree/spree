require 'spec_helper'

describe 'Zones', type: :feature do
  stub_authorization!

  before do
    Spree::Zone.delete_all
    visit spree.admin_path
    click_link 'Configuration'
  end

  context 'show' do
    it 'displays existing zones' do
      create(:zone, name: 'eastern', description: 'zone is eastern')
      create(:zone, name: 'western', description: 'cool san fran')
      click_link 'Zones'

      within_row(1) { expect(page).to have_content('eastern') }
      within_row(2) { expect(page).to have_content('western') }

      click_link 'zones_order_by_description_title'

      within_row(1) { expect(page).to have_content('western') }
      within_row(2) { expect(page).to have_content('eastern') }
    end
  end

  context 'create' do
    it 'allows an admin to create a new zone' do
      click_link 'Zones'
      within find('#contentHeader') do
        click_link 'admin_new_zone_link'
      end
      expect(page).to have_content('New Zone')
      fill_in 'zone_name', with: 'japan'
      fill_in 'zone_description', with: 'japanese time zone'
      click_button 'Create'
      expect(page).to have_content('successfully created!')
    end
  end
end
