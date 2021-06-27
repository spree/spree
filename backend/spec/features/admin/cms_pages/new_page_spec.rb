require 'spec_helper'

describe 'New Page', type: :feature do
  stub_authorization!

  context 'when a user creates a new page' do
    before do
      visit spree.new_admin_cms_page_path
    end

    it 'shows in the contextual header bar the user is creating a new page' do
      within('h1') do
        expect(page).to have_text Spree.t('admin.cms.new_page')
      end
    end

    it 'shows the breadcrumb link back to all pages' do
      expect(page).to have_text Spree.t('admin.cms.all_pages')
    end

    it 'has no missing translations' do
      expect(page).not_to have_css('.translation_missing', visible: :all)
    end
  end

  context 'when a user tries to create a new page with no title' do
    before do
      visit spree.new_admin_cms_page_path
    end

    it "warns that the title can't be blank" do
      click_on 'Create'
      expect(page).to have_text ("Title can't be blank")
    end
  end

  context 'when a user tries to create a page with a duplicate slug' do
    let!(:store_1) { create(:store, default: true) }
    let!(:cms_page) { create(:cms_standard_page, title: 'About Us', store: store_1) }

    before do
      visit spree.new_admin_cms_page_path
    end

    it 'warns the user that the slug has already been taken', js: true do
      fill_in 'Title *', with: 'About Us'
      select2 store_1.unique_name, from: 'Stores'

      click_on 'Create'
      expect(page).to have_text ('Slug has already been taken')
    end
  end
end
