require 'spec_helper'

describe 'Visiting the homepage with featured article section', type: :feature, js: true do
  let!(:store) { Spree::Store.default }

  let!(:en_feature_page) { create(:cms_feature_page, store: store, locale: 'en', slug: 'english-feature') }
  let!(:en_homepage) { create(:cms_homepage, store: store, locale: 'en') }
  let!(:en_hp_featured_article_section) { create(:cms_featured_article_section, cms_page: en_homepage, linked_resource: en_feature_page) }

  let!(:fr_feature_page) { create(:cms_feature_page, store: store, locale: 'fr', slug: 'french-feature') }
  let!(:fr_homepage) { create(:cms_homepage, store: store, locale: 'fr') }
  let!(:fr_hp_featured_article_section) { create(:cms_featured_article_section, cms_page: fr_homepage, linked_resource: fr_feature_page) }

  context 'when page is viewed in default language' do
    before do
      en_featured_article_section = Spree::CmsSection.find(en_hp_featured_article_section.id)

      en_featured_article_section.update!(title: 'Featured Article Title', button_text: 'Featured Article Button Text')
      visit spree.root_path
    end

    it 'the Featured Article section displays the link without a language denomination' do
      expect(page).to have_selector(:css, 'a[href="/pages/english-feature"]', text: "FEATURED ARTICLE BUTTON TEXT")
    end

    it 'the Featured Article section displays the title text' do
      expect(page).to have_content('Featured Article Title')
    end
  end

  context 'when page is viewed in a none default language' do
    before do
      store.update(default_locale: 'en', supported_locales: 'en,fr')

      fr_featured_article_section = Spree::CmsSection.find(fr_hp_featured_article_section.id)

      fr_featured_article_section.update!(title: 'FR_FA_Title', button_text: 'FR FA BTN TXT')
      visit '/fr'
    end

    it 'the Featured Article section displays the link without a language denomination' do
      expect(page).to have_selector(:css, 'a[href="/fr/pages/french-feature"]', text: "FR FA BTN TXT")
    end

    it 'the Featured Article section displays the title text translated' do
      expect(page).to have_content('FR_FA_Title')
    end
  end
end
