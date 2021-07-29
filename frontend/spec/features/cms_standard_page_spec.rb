require 'spec_helper'

describe 'cms_page standard page', type: :feature, js: true do
  let!(:store) { create(:store, default: true, supported_currencies: 'USD', supported_locales: 'en,fr') }

  describe 'page' do
    let!(:cms_page) { create(:cms_standard_page, store: store, locale: 'en', content: '<h2>About Us</h2>') }

    before do
      visit spree.page_path(cms_page.slug)
    end

    it 'displays content' do
      expect(page).to have_text('About Us')
    end

    it 'displays title as page title if no meta_title is set' do
      expect(page).to have_title("#{cms_page.title} - #{store.name}")
    end

    it 'redirects to homepage when language is changed via locale selector' do
      find('#internationalization-button-desktop').click
      find('#switch_to_locale').find(:xpath, 'option[2]').select_option

      expect(page).to have_text('We Will Be Back')
    end
  end

  describe 'page has metas' do
    let!(:cms_page_with_metas) do
      create(:cms_standard_page, store: store,
                                 locale: 'en',
                                 content: '<h2>Contact Us</h2>',
                                 meta_title: 'Hello From Contact Us Page',
                                 meta_description: 'This is a wonderful meta description, search engines will be happy!')
    end

    before do
      visit spree.page_path(cms_page_with_metas.slug)
    end

    it 'displays meta_title as the set meta_title when one is set' do
      expect(page).to have_title("#{cms_page_with_metas.meta_title} - #{store.name}")
    end

    it 'displays meta_description as the set meta_description when one is set' do
      expect(page).to have_meta(:description, cms_page_with_metas.meta_description)
    end
  end
end
