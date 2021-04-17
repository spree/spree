require 'spec_helper'

describe 'Menus Index', type: :feature do
  stub_authorization!

  context 'when no menus are present' do
    before do
      visit spree.admin_menus_path
    end

    it 'prompts the user to create a menu' do
      expect(page).to have_text Spree.t('admin.navigation.you_have_no_menus')
    end
  end

  context 'when menus are present' do
    let!(:store_1) { create(:store) }
    let!(:store_2) { create(:store) }
    let!(:store_3) { create(:store) }

    let!(:main_menu) { create(:menu, name: 'Main Menu', store_ids: [store_1.id, store_3.id]) }
    let!(:footer_menu) { create(:menu, name: 'Footer Menu') }

    before do
      visit spree.admin_menus_path
    end

    it 'lists all of the menus in the table' do
      within_table('menusTable') do
        expect(page).to have_text 'Main Menu'
        expect(page).to have_text 'Footer Menu'
      end
    end

    it 'lists each menu with its store ' do
      within_table('menusTable') do
        expect(page).to have_text 'Main Menu'
        expect(page).to have_text 'Footer Menu'
        expect(page).to have_text store_1.unique_name
        expect(page).to have_text store_3.unique_name
        expect(page).not_to have_text store_2.unique_name
      end
    end

    it 'does not prompt you to create your first menu' do
      expect(page).not_to have_text Spree.t('admin.navigation.you_have_no_menus')
    end

    it 'has no missing translations' do
      expect(page).not_to have_css('.translation_missing', visible: :all)
    end
  end

  context 'when a user clicks Add New Menu' do
    before do
      visit spree.admin_menus_path
      within('div#contentHeader') do
        click_on 'Add New Menu'
      end
    end

    it 'they are taken to the new menu page' do
      within('h1') do
        expect(page).to have_text Spree.t('admin.navigation.new_menu')
      end

      expect(page).to have_text Spree.t('admin.navigation.new_menu')
      fill_in 'Name', with: 'My Super Menu'
    end
  end
end
