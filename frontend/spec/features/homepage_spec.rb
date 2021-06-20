require 'spec_helper'

describe 'homepage', type: :feature, js: true do
  let(:eu_store_hp) { create(:store, default: true, supported_currencies: 'EUR', default_locale: 'de', supported_locales: 'de,fr') }

  after do
    create(:store, default: true)

    eu_store_hp.update(default_locale: nil)
    I18n.locale = :en
    Spree::Frontend::Config[:locale] = :en
  end

  context 'meta title' do
    let!(:homepage_mt) { create(:cms_homepage, store: eu_store_hp, locale: 'de') }

    before { visit spree.root_path }

    it 'displays page title as page title if no meta_title is set' do
      expect(page).to have_title("#{homepage_mt.title} - #{eu_store_hp.name}")
    end

    it 'displays page meta_title as page title if meta_title is set' do
      expect(page).to have_title("#{homepage_mt.meta_title} - #{eu_store_hp.name}")
    end
  end

  context 'meta description - when no cms_homepage is set and store has no meta data set' do
    before { visit spree.root_path }

    it 'returns store_seo_description falling back to store name' do
      expect(page).to have_meta(:description, eu_store_hp.name)
    end
  end

  context 'meta description - when no cms_homepage is set and store has meta title set' do
    let!(:current_store_with_seo_title) { create(:store, default: true, seo_title: 'Store SEO Title') }

    before { visit spree.root_path }

    it 'uses store seo_title as meta_description if no page meta_description or store meta_description have been set' do
      expect(page).to have_meta(:description, current_store_with_seo_title.seo_title)
    end
  end

  context 'meta description - when no cms_homepage is set and store has meta description set' do
    let!(:current_store_with_seo_meta_desscription) { create(:store, default: true, meta_description: 'Store Meta Description') }

    before { visit spree.root_path }

    it 'uses store seo_title as meta_description if no page meta_description or store meta_description have been set' do
      expect(page).to have_meta(:description, current_store_with_seo_meta_desscription.meta_description)
    end
  end

  context 'meta description - when cms_homepage is set and has no meta description' do
    let!(:homepage_with_no_meta_description) { create(:cms_homepage, store: eu_store_hp, locale: 'de') }

    before { visit spree.root_path }

    it 'falls back to store seo_meta_description' do
      expect(page).to have_meta(:description, eu_store_hp.name)
    end
  end

  context 'meta description - when cms_homepage is set and has meta description' do
    let!(:homepage_with_meta_description) { create(:cms_homepage, store: eu_store_hp, locale: 'de', meta_description: 'Page Meta Description') }

    before { visit spree.root_path }

    it 'falls back to store seo_meta_description' do
      expect(page).to have_meta(:description, homepage_with_meta_description.meta_description)
    end
  end

  context 'when no homepage is set' do
    before { visit spree.root_path }

    it 'the index page is still accesable with a back soon message' do
      expect(page).to have_text('We will be back.')
    end
  end

  context 'when homepage is set' do
    let!(:homepage) { create(:cms_homepage, store: eu_store_hp, locale: 'de') }
    let!(:hp_section) { create(:cms_featured_article_section, cms_page: homepage) }

    before do
      hp_sec = Spree::CmsSection.find(hp_section.id)

      hp_sec.content[:title] = 'Hallo, das ist der Feature-Artikel auf der Homepage'
      hp_sec.save!
      hp_sec.reload

      visit spree.root_path
    end

    it 'displays the sections content' do
      expect(page).to have_text('Hallo, das ist der Feature-Artikel auf der Homepage')
    end
  end

  context 'when the index page is viewed using a none default language but no cms_homepage is available for the current language' do
    let!(:homepage_de) { create(:cms_homepage, store: eu_store_hp, locale: 'de') }
    let!(:hp_section_de) { create(:cms_featured_article_section, cms_page: homepage_de) }

    before do
      Spree::Frontend::Config[:locale] = :fr

      hp_sec_de = Spree::CmsSection.find(hp_section_de.id)

      hp_sec_de.content[:title] = 'Hallo, das ist der Feature-Artikel auf der Homepage'
      hp_sec_de.save!
      hp_sec_de.reload

      visit spree.root_path
    end

    after do
      Spree::Frontend::Config[:locale] = nil
    end

    it 'displays the cms_homepage for the stores default language' do
      expect(page).to have_text('Hallo, das ist der Feature-Artikel auf der Homepage')
    end
  end

  context 'when the index page is viewed using none default language and translation is present' do
    let!(:homepage_de) { create(:cms_homepage, store: eu_store_hp, locale: 'de') }
    let!(:homepage_fr) { create(:cms_homepage, store: eu_store_hp, locale: 'fr') }
    let!(:hp_section_de) { create(:cms_featured_article_section, cms_page: homepage_de) }
    let!(:hp_section_fr) { create(:cms_featured_article_section, cms_page: homepage_fr) }

    before do
      Spree::Frontend::Config[:locale] = :fr

      hp_sec_de = Spree::CmsSection.find(hp_section_de.id)

      hp_sec_de.content[:title] = 'Hallo, das ist der Feature-Artikel auf der Homepage'
      hp_sec_de.save!
      hp_sec_de.reload

      hp_sec_fr = Spree::CmsSection.find(hp_section_fr.id)

      hp_sec_fr.content[:title] = "Bonjour, c'est l'article vedette sur la page d'accueil"
      hp_sec_fr.save!
      hp_sec_fr.reload

      visit spree.root_path
    end

    after do
      Spree::Frontend::Config[:locale] = nil
    end

    it 'displays the correct cms_homepage' do
      expect(page).to have_text("Bonjour, c'est l'article vedette sur la page d'accueil")
    end
  end

  context 'homepage is displayed for the current store' do
    let(:us_store_hp) { create(:store, supported_currencies: 'USD', default_locale: 'en', supported_locales: 'en') }
    let!(:homepage_eu_store) { create(:cms_homepage, store: eu_store_hp, locale: 'de') }
    let!(:homepage_us_store) { create(:cms_homepage, store: us_store_hp, locale: 'en') }
    let!(:hp_section_de) { create(:cms_featured_article_section, cms_page: homepage_eu_store) }
    let!(:hp_section_us) { create(:cms_featured_article_section, cms_page: homepage_us_store) }

    before do
      eu_store_hp.update(default: false)
      us_store_hp.update(default: true)
      hp_eu_sec = Spree::CmsSection.find(homepage_eu_store.id)

      hp_eu_sec.content[:title] = 'Willkommen in unserem EU-Shop'
      hp_eu_sec.save!
      hp_eu_sec.reload

      hp_us_sec = Spree::CmsSection.find(homepage_us_store.id)

      hp_us_sec.content[:title] = 'Welcome To The US Store'
      hp_us_sec.save!
      hp_us_sec.reload

      visit spree.root_path
    end

    after do
      eu_store_hp.update(default: true)
      us_store_hp.update(default: false)
    end

    it 'displays the correct homepage for the current store' do
      expect(page).to have_text('Welcome To The US Store')
    end
  end
end
