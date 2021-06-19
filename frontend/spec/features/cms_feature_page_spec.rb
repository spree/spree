require 'spec_helper'

describe 'cms_page feature page', type: :feature, js: true do
  let!(:store) { create(:store, default: true, supported_currencies: 'USD') }

  describe 'feature page' do
    let!(:cms_feature_page) { create(:cms_feature_page, store: store, locale: 'en', content: '<h2>About Us</h2>') }
    let!(:fa_section) { create(:cms_featured_article_section, cms_page: cms_feature_page) }

    before do
      fa_sect = Spree::CmsSection.find(fa_section.id)
      fa_sect.content[:title] = 'Hot Sellers This Season'
      fa_sect.save!
      fa_sect.reload

      visit spree.page_path(cms_feature_page.slug)
    end

    it 'does not display content, even if it is present in the database' do
      expect(page).not_to have_text('About Us')
    end

    it 'displays title as page title if no meta_title is set' do
      expect(page).to have_title("#{cms_feature_page.title} - #{store.name}")
    end

    it 'displays sections' do
      expect(page).to have_text('Hot Sellers This Season')
    end
  end

  describe 'when feature page has metas' do
    let!(:cms_feature_page_with_metas) do
      create(:cms_feature_page, store: store,
                                locale: 'en',
                                content: '<h2>Contact Us</h2>',
                                meta_title: 'Hello From Contact Us Page',
                                meta_description: 'This is a wonderful meta description, search engines will be happy!')
    end

    before do
      visit spree.page_path(cms_feature_page_with_metas.slug)
    end

    it 'displays meta_title as the set meta_title when one is set' do
      expect(page).to have_title("#{cms_feature_page_with_metas.meta_title} - #{store.name}")
    end

    it 'displays meta_description as the set meta_description when one is set' do
      expect(page).to have_meta(:description, cms_feature_page_with_metas.meta_description)
    end
  end
end
