require 'spec_helper'

module Spree
  describe 'Countries', type: :feature do
    stub_authorization!

    it 'deletes a state', js: true do
      visit spree.admin_countries_path
      click_link 'New Country'

      fill_in 'Name', with: 'Brazil'
      fill_in 'ISO Name', with: 'BRAZIL'
      fill_in 'ISO Alpha-2', with: 'BR'
      fill_in 'ISO Alpha-3', with: 'BRL'
      check 'States Required'
      uncheck 'Zip Code Required'

      click_button 'Create'

      expect(page).to have_content('Brazil')
      expect(page).to have_content('BRL')
      expect(page).to have_content('Yes')
      expect(page).to have_content('No')

      accept_confirm do
        click_icon :delete
      end
      expect(page).to have_content('has been successfully removed!')

      expect { Country.find(country.id) }.to raise_error(StandardError)
    end
  end
end
