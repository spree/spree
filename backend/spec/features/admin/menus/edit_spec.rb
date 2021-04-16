require 'spec_helper'

describe 'Editing an existing menu', type: :feature do
  stub_authorization!

  let!(:main_menu) { create(:menu, name: 'Main Menu') }

  context 'user can add menu items' do
    before do
      visit spree.edit_admin_menu_path(main_menu)
    end

    it 'shows' do
      click_on 'Add New Item'

      within('div#contentHeader') do
        expect(page).to have_text 'New Menu Item'
      end
    end
  end
end
