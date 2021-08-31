require 'spec_helper'

describe 'Featured Article section', type: :feature do
  stub_authorization!

  section_type = 'Featured Article'

  let!(:store) { Spree::Store.default }
  let!(:feature_page) { create(:cms_feature_page, store: store, title: 'Test Page') }
  let!(:taxon) { create(:taxon) }
  let!(:product) { create(:product) }
  let!(:cms_standard_page) { create(:cms_standard_page, store: store) }
  let!(:homepage) { create(:cms_homepage, store: store, title: 'Super Home Page') }
  let!(:section) { create(:cms_featured_article_section, cms_page: feature_page, name: "Test #{section_type}") }

  before do
    visit spree.edit_admin_cms_page_cms_section_path(feature_page, section)
  end

  context 'editing new page', js: true  do
    it 'loads with correct defaults setings' do
      expect(page).to have_field('Name *', with: "Test #{section_type}")
      expect(page).to have_select('Section Type', selected: section_type)
      expect(page).to have_content("Options For: #{section_type}")
      expect(page).to have_select('Gutters', selected: 'No Gutters')
    end

    it 'saves WYSIWYG content to database' do
      rte_content = 'Ipsum blanditiis labore voluptates vero asperiores ullam excepturi'

      page.execute_script("$(tinymce.editors[0].setContent('#{rte_content}'))")

      click_on 'Update'

      expect(page).to have_field(id: 'cms_section_rte_content', with: "<p>#{rte_content}</p>", visible: :hidden, disabled: false)
      assert_admin_flash_alert_success('Section "Test Featured Article" has been successfully updated!')
    end

    it 'saves taxon path and loads it back into the view' do
      select2 taxon.name, from: 'Taxon', search: true

      click_on 'Update'

      expect(page).to have_content(taxon.permalink)
      assert_admin_flash_alert_success('Section "Test Featured Article" has been successfully updated!')
    end

    it 'saves product path and loads it back into the view' do
      select2 'Product', from: 'Link To'

      click_on 'Update'

      select2 product.name, from: 'Product', search: true

      click_on 'Update'

      expect(page).to have_content(product.slug)
      assert_admin_flash_alert_success('Section "Test Featured Article" has been successfully updated!')
    end

    it 'saves page path and loads it back into the view' do
      select2 'Page', from: 'Link To'

      click_on 'Update'

      select2 cms_standard_page.title, from: 'Page', search: true

      click_on 'Update'

      expect(page).to have_content(cms_standard_page.slug)
      assert_admin_flash_alert_success('Section "Test Featured Article" has been successfully updated!')
    end

    it 'does not display homepages in Link To Page results' do
      select2 'Page', from: 'Link To'

      click_on 'Update'

      select2_open label: 'Page'
      select2_search homepage.title, label: 'Page'

      wait_for_ajax do
        expect(page).to have_text('No results found')
      end
    end

    it 'allows admin to enter and save details' do
      fill_in 'Title', with: 'Trendy Styles'
      fill_in 'Subtitle', with: 'Shop Today'
      fill_in 'Button Text', with: 'Learn More'
      select2('Gutters', from: 'Gutters', exact_text: true)

      click_on 'Update'

      expect(page).to have_field('Title', with: 'Trendy Styles')
      expect(page).to have_field('Subtitle', with: 'Shop Today')
      expect(page).to have_field('Button Text', with: 'Learn More')
      expect(page).to have_select('Gutters', selected: 'Gutters')
    end

    it 'allows changing of the section name' do
      fill_in 'Name *', with: 'My New Section Name'
      click_on 'Update'
      expect(page).to have_field('Name *', with: 'My New Section Name')
    end
  end
end
