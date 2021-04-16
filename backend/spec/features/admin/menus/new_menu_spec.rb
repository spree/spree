require 'spec_helper'

describe 'New Menu', type: :feature do
  stub_authorization!

  context 'when user visits new menu page' do
    before do
      visit spree.new_admin_menu_path
    end

    it 'shows in the contextual header bar the user is creating a new menu' do
      within('h1') do
        expect(page).to have_text Spree.t('admin.navigation.new_menu')
      end
    end

    it 'shows the breadcrumb link back to all menus' do
      expect(page).to have_text Spree.t('admin.navigation.all_menus')
    end

    it 'has no missing translations' do
      expect(page).not_to have_css('.translation_missing', visible: :all)
    end
  end

  context 'when a user tries to create a menu with no name' do
    before do
      visit spree.new_admin_menu_path
    end

    it "warns that the Name can't be blank" do
      click_on 'Create'
      expect(page).to have_text ("Name can't be blank")
    end
  end

  context 'when a user tries to create a menu with a duplicate name' do
    let!(:main_menu) { create(:menu, name: 'Main Menu') }

    before do
      visit spree.new_admin_menu_path
    end

    it 'warns the user that the Name has already been taken' do
      fill_in 'Name', with: 'Main Menu'
      click_on 'Create'
      expect(page).to have_text ('Name has already been taken')
    end
  end

  context 'user can create a new menu', js: true do
    let!(:store_1) { create(:store) }
    let!(:store_2) { create(:store) }
    let!(:store_3) { create(:store) }

    before do
      visit spree.new_admin_menu_path
    end

    it 'with stores' do
      fill_in 'Name', with: 'Main Menu'

      select2 store_1.unique_name, from: 'Stores'
      select2 store_3.unique_name, from: 'Stores'
      click_on 'Create'

      assert_admin_flash_alert_success('Menu "Main Menu" has been successfully created!')
      expect(page).to have_text 'Main Menu has no items. Click the Add New Item button to begin adding links to this menu.'
      expect(page).to have_selector('a', text: Spree.t('admin.navigation.add_new_item'))

       expect(page).not_to have_css('.translation_missing', visible: :all)
    end
  end
end
