require 'spec_helper'

describe 'Rich Text Content section', type: :feature do
  stub_authorization!

  section_type = 'Rich Text Content'

  let!(:store) { Spree::Store.default }
  let!(:feature_page) { create(:cms_feature_page, store: store, title: 'Test Page') }
  let!(:section) { create(:cms_rich_text_content_section, cms_page: feature_page, name: "Test #{section_type}") }

  before do
    visit spree.edit_admin_cms_page_cms_section_path(feature_page, section)
  end

  context 'editing new page', js: true  do
    it 'loads with correct defaults setings' do
      expect(page).to have_field('Name *', with: "Test #{section_type}")
      expect(page).to have_select('Section Type', selected: section_type)
      expect(page).to have_content("Options For: #{section_type}")
    end

    it 'saves WYSIWYG content to database' do
      rte_content = 'Ipsum blanditiis labore voluptates vero asperiores ullam excepturi'

      page.execute_script("$(tinymce.editors[0].setContent('#{rte_content}'))")

      click_on 'Update'

      expect(page).to have_field(id: 'cms_section_rte_content', with: "<p>#{rte_content}</p>", visible: :hidden, disabled: false)
      assert_admin_flash_alert_success('Section "Test Rich Text Content" has been successfully updated!')
    end


    it 'allows changing of the section name' do
      fill_in 'Name *', with: 'My New Section Name'
      click_on 'Update'
      expect(page).to have_field('Name *', with: 'My New Section Name')
    end
  end
end
