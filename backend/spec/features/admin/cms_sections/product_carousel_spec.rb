require 'spec_helper'

describe 'Product Carousel section', type: :feature do
  stub_authorization!

  section_type = 'Product Carousel'

  let!(:store) { Spree::Store.default }
  let!(:feature_page) { create(:cms_feature_page, store: store, title: 'Test Page') }
  let!(:taxon) { create(:taxon) }
  let!(:section) { create(:cms_product_carousel_section, cms_page: feature_page, name: "Test #{section_type}") }

  before do
    visit spree.edit_admin_cms_page_cms_section_path(feature_page, section)
  end

  context 'editing new page', js: true  do
    it 'loads with correct defaults setings' do
      expect(page).to have_field('Name *', with: "Test #{section_type}")
      expect(page).to have_select('Section Type', selected: section_type)
      expect(page).to have_content("Options For: #{ section_type}")
    end

    it 'saves taxon path and loads it back into the view' do
      select2 taxon.name, from: 'Taxon', search: true

      click_on 'Update'

      expect(page).to have_content(taxon.permalink)
      assert_admin_flash_alert_success('Section "Test Product Carousel" has been successfully updated!')
    end

    it 'allows changing of the section name' do
      fill_in 'Name *', with: 'My New Section Name'
      click_on 'Update'
      expect(page).to have_field('Name *', with: 'My New Section Name')
    end
  end
end
