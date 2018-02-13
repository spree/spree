require 'spec_helper'

module Spree
  describe 'Countries', type: :feature do
    stub_authorization!

    it 'deletes a state', js: true do
      visit spree.admin_countries_path
      click_link 'New Country'

      fill_in 'Name', with: 'Brazil'
      fill_in 'Iso Name', with: 'BRL'
      click_button 'Create'

      spree_accept_alert do
        click_icon :delete
        wait_for_ajax
      end

      expect { Country.find(country.id) }.to raise_error(StandardError)
    end
  end
end
