require 'spec_helper'

describe 'CMS Pages Index', type: :feature do
  stub_authorization!

  context 'when no cms pages are present' do
    before do
      visit spree.admin_cms_pages_path
    end

    it 'prompts the user to create a cms page' do
      expect(page).to have_text 'You have no Pages, click the + Add New Page button to get started.'
    end
  end

  context 'when cms pages are present' do
    let!(:main_store) { Spree::Store.default }
    let!(:other_store) { create(:store) }
    let!(:about_us_en) { create(:cms_standard_page, title: 'About Us', locale: 'en', store: main_store) }
    let!(:about_us_fr) { create(:cms_standard_page, title: 'À propos de nous', locale: 'fr', store: main_store) }
    let!(:feature_page_en) { create(:cms_feature_page, title: 'Amazing PLP', locale: 'en', store: main_store) }
    let!(:page_other_store) { create(:cms_standard_page, title: 'Privacy Policy', locale: 'en', store: other_store) }

    before do
      I18n.backend.store_translations(:fr,
                                      spree: {
                                        i18n: {
                                          this_file_language: 'Français (FR)'
                                        }
                                      })

      main_store.update(supported_locales: 'en,fr')
      visit spree.admin_cms_pages_path
    end

    it 'lists each cms_page' do
      within_table('pagesTable') do
        expect(page).to have_text 'About Us'
        expect(page).to have_text 'À propos de nous'
        expect(page).to have_text 'Amazing PLP'
      end
    end

    it 'does not list cms_page from other store' do
      within_table('pagesTable') do
        expect(page).not_to have_text 'Privacy Policy'
      end
    end

    it 'does not prompt you to create your first cms page' do
      expect(page).not_to have_text 'You have no Pages, click the + Add New Page button to get started.'
    end

    it 'has no missing translations' do
      expect(page).not_to have_css('.translation_missing', visible: :all)
    end

    describe 'when filtering', js: true do
      it 'is able to filter by name' do
        click_on 'Filter'
        fill_in 'Title', with: 'À propos de nous'
        click_on 'Search'

        within_table('pagesTable') do
          expect(page).to have_text 'À propos de nous'
          expect(page).not_to have_text 'About Us'
        end
      end

      it 'is able to filter by language' do
        click_on 'Filter'
        select2 'Français (FR)', from: 'Language'
        click_on 'Search'

        within_table('pagesTable') do
          expect(page).to have_text 'À propos de nous'
          expect(page).not_to have_text 'About Us'
        end
      end

      it 'is able to filter by type' do
        click_on 'Filter'
        select2 'Feature Page', from: 'Type'
        click_on 'Search'

        within_table('pagesTable') do
          expect(page).to have_text 'Amazing PLP'
          expect(page).not_to have_text 'À propos de nous'
          expect(page).not_to have_text 'About Us'
        end
      end
    end
  end

  context 'when a user clicks Add New Page' do
    before do
      visit spree.admin_cms_pages_path
      within('div#contentHeader') do
        click_on 'Add New Page'
      end
    end

    it 'they are taken to the new cms_page' do
      within('h1') do
        expect(page).to have_text 'New Page'
      end
    end
  end
end
