require 'spec_helper'

module Spree
  describe 'Countries', type: :feature do
    stub_authorization!

    it 'deletes a state', js: true do
      visit spree.admin_countries_path
      click_link 'New Country'

      fill_in 'Name', with: 'Brazil'
      fill_in 'Iso Name', with: 'BRL'
      fill_in 'Iso', with: 'BR'
      fill_in 'Iso3', with: 'BRL'
      click_button 'Create'

      accept_confirm do
        click_icon :delete
      end
      expect(page).to have_content('has been successfully removed!')

      expect { Country.find(country.id) }.to raise_error(StandardError)
    end
  end
end
