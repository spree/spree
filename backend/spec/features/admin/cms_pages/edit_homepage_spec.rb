require 'spec_helper'

describe 'Edit Homepage', type: :feature do
  stub_authorization!

  context 'when a user creates a Homepage' do
    let!(:store_hp) { create(:store, name: 'Super Store', supported_locales: 'en,fr') }

    before do
      I18n.backend.store_translations(:fr,
                                      spree: {
                                        i18n: {
                                          this_file_language: 'Français (FR)'
                                        }
                                      })

      visit spree.new_admin_cms_page_path

      fill_in 'Title *', with: 'Homepage (English)'
      select 'Homepage', from: 'cms_page[type]'

      click_on 'Create'
    end

    it 'saves the basic setting fields and generates a slug' do
      expect(page).to have_field('Title *', with: 'Homepage (English)')
      expect(page).to have_field('Slug', disabled: true)
    end

    it 'displays the Section Manager' do
      expect(page).to have_selector(:link_or_button, 'Add New Section')
      expect(page).to have_content('Mobile')
      expect(page).to have_content('Tablet')
      expect(page).to have_content('Desktop')
      expect(page).to have_content('Add your first section to this page by clicking the + Add New Section button above.')
    end

    it 'user can enter and exit full screen mode', js: true do
      find('[id="cmsSectionEditorFullScreen"]').click

      expect(page).to have_selector('body[data-sections-editor-full-screen]')
    end

    it 'displays the language of the page' do
      expect(page).to have_text ('English (US)')
    end

    it 'allows user to toggle visability' do
      expect(page).to have_text ('Visible')

      find(:xpath, '//*[@id="cms_page_visible"]/..').click

      expect(page).to have_text ('Draft Mode')
    end

    it 'allows user to switch language', js: true do
      find('[aria-controls="collapsePageSettings"]').click

      select2 'Français (FR)', from: 'Language'

      click_on 'Update'

      expect(page).to have_text('Français (FR)')
    end
  end
end
