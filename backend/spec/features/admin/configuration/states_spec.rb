require 'spec_helper'

describe 'States', type: :feature do
  stub_authorization!

  let!(:country) { create(:country) }

  before do
    @hungary = Spree::Country.create!(name: 'Hungary', iso_name: 'Hungary', iso: 'HU', iso3: 'HUN')
  end

  def go_to_states_page
    visit spree.admin_country_states_path(country)
    expect(page).to have_selector('#new_state_link')
    page.execute_script('$.fx.off = true')
  end

  context 'admin visiting states listing' do
    let!(:state) { create(:state, country: country) }

    it 'correctly displays the states' do
      visit spree.admin_country_states_path(country)
      expect(page).to have_content(state.name)
    end
  end

  context 'creating and editing states' do
    it 'allows an admin to edit existing states', js: true do
      go_to_states_page
      choose_country(country.name)

      click_link 'new_state_link'
      fill_in 'state_name', with: 'Calgary'
      fill_in 'Abbreviation', with: 'CL'
      click_button 'Create'
      expect(page).to have_content('successfully created!')
      expect(page).to have_content('Calgary')
    end

    it 'allows an admin to create states for non default countries', js: true do
      go_to_states_page
      choose_country(@hungary.name)

      click_link 'new_state_link'
      fill_in 'state_name', with: 'Pest megye'
      fill_in 'Abbreviation', with: 'PE'
      click_button 'Create'
      expect(page).to have_content('successfully created!')
      expect(page).to have_content('Pest megye')
      expect(page).to have_css('.form-group[data-hook="country"]', text: 'Hungary')
    end

    it 'shows validation errors', js: true do
      go_to_states_page
      choose_country(country.name)

      click_link 'new_state_link'

      fill_in 'state_name', with: ''
      fill_in 'Abbreviation', with: ''
      click_button 'Create'
      expect(page).to have_content("Name can't be blank")
    end

    def choose_country(country)
      select2 country, css: '.form-group[data-hook="country"]'
    end
  end
end
