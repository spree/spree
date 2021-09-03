require 'spec_helper'

describe 'Hero Image section', type: :feature do
  stub_authorization!

  section_type = 'Hero Image'

  let!(:store) { Spree::Store.default }
  let!(:feature_page) { create(:cms_feature_page, store: store, title: 'Test Page') }
  let!(:taxon) { create(:taxon) }
  let!(:product) { create(:product) }
  let!(:cms_standard_page) { create(:cms_standard_page, store: store) }
  let!(:homepage) { create(:cms_homepage, store: store, title: 'Super Home Page') }
  let!(:section) { create(:cms_hero_image_section, cms_page: feature_page, name: "Test #{section_type}") }
  let(:file_path) { Rails.root + '../../spec/support/ror_ringer.jpeg' }

  before do
    visit spree.edit_admin_cms_page_cms_section_path(feature_page, section)
  end

  context 'editing new page', js: true  do
    it 'loads with correct defaults setings' do
      expect(page).to have_field('Name *', with: "Test #{section_type}")
      expect(page).to have_select('Section Type', selected: section_type)
      expect(page).to have_content("Options For: #{section_type}")
      expect(page).to have_select('Gutters', selected: 'No Gutters')
      expect(page).to have_select('Fit To', selected: 'Screen')
    end

    it 'saves taxon path and loads it back into the view' do
      select2 taxon.name, from: 'Taxon', search: true

      click_on 'Update'

      expect(page).to have_content(taxon.permalink)
      assert_admin_flash_alert_success('Section "Test Hero Image" has been successfully updated!')
    end

    it 'admin should be able to add image' do
      attach_file('cms_section_image_one', file_path)

      click_button 'Update'

      expect(page).to have_content('successfully updated!')
      expect(page).to have_css('.admin-img-holder img')
    end

    it 'saves product path and loads it back into the view' do
      select2 'Product', from: 'Link To'

      click_on 'Update'

      select2 product.name, from: 'Product', search: true

      click_on 'Update'

      expect(page).to have_content(product.slug)
      assert_admin_flash_alert_success('Section "Test Hero Image" has been successfully updated!')
    end

    it 'saves page path and loads it back into the view' do
      select2 'Page', from: 'Link To'

      click_on 'Update'

      select2 cms_standard_page.title, from: 'Page', search: true

      click_on 'Update'

      expect(page).to have_content(cms_standard_page.slug)
      assert_admin_flash_alert_success('Section "Test Hero Image" has been successfully updated!')
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
      fill_in 'Button Text', with: 'Learn More'
      select2('Gutters', from: 'Gutters', exact_text: true)
      select2('Container', from: 'Fit To', exact_text: true)

      click_on 'Update'

      expect(page).to have_field('Title', with: 'Trendy Styles')
      expect(page).to have_field('Button Text', with: 'Learn More')
      expect(page).to have_select('Fit To', selected: 'Container')
      expect(page).to have_select('Gutters', selected: 'Gutters')
    end

    it 'allows changing of the section name' do
      fill_in 'Name *', with: 'My New Section Name'
      click_on 'Update'
      expect(page).to have_field('Name *', with: 'My New Section Name')
    end
  end
end
