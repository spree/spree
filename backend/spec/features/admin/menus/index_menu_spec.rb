require 'spec_helper'

describe 'Menus Index', type: :feature do
  stub_authorization!

  let!(:location_header) { create(:menu_location) }
  let!(:location_footer) { create(:menu_location, name: 'Footer') }

  context 'when no menus are present' do
    before do
      visit spree.admin_menus_path
    end

    it 'prompts the user to create a menu' do
      expect(page).to have_text Spree.t('admin.navigation.you_have_no_menus')
    end
  end

  context 'when menus are present' do
    let!(:other_store) { create(:store) }
    let!(:main_menu) { create(:menu, name: 'Main Menu') }
    let!(:main_menu_fr) { create(:menu, name: 'Main Menu FR', locale: 'fr') }
    let!(:footer_menu) { create(:menu, name: 'Footer Menu', location: 'footer') }

    let!(:main_menu_other_store) { create(:menu, name: 'Other Store Main Menu', store: other_store) }

    before do
      visit spree.admin_menus_path
      I18n.backend.store_translations(:fr,
                                      spree: {
                                        i18n: {
                                          this_file_language: 'Français (FR)'
                                        }
                                      })
    end

    it 'lists each menu' do
      within_table('menusTable') do
        expect(page).to have_text 'Main Menu'
        expect(page).to have_text 'Footer Menu'
      end
    end

    it 'does not list menus from other store' do
      within_table('menusTable') do
        expect(page).not_to have_text 'Other Store Main Menu'
      end
    end

    it 'does not prompt you to create your first menu' do
      expect(page).not_to have_text Spree.t('admin.navigation.you_have_no_menus')
    end

    it 'has no missing translations' do
      expect(page).not_to have_css('.translation_missing', visible: :all)
    end

    describe 'when filtering', js: true do
      it 'is able to filter by name' do
        click_on 'Filter'
        fill_in 'Name', with: 'Main Menu FR'
        click_on 'Search'

        expect(page).to have_text 'Main Menu FR'
        expect(page).not_to have_text 'Footer Menu'
      end

      it 'is able to filter by language' do
        click_on 'Filter'
        select2 'Français (FR)', from: 'Language'
        click_on 'Search'

        expect(page).to have_text 'Main Menu FR'
        expect(page).not_to have_text 'Footer Menu'
      end

      it 'is able to filter by location' do
        click_on 'Filter'
        select2 'Footer', from: 'Location'
        click_on 'Search'

        expect(page).to have_text 'Footer Menu'
        expect(page).not_to have_text 'Main Menu'
      end
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
