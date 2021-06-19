require 'spec_helper'

describe 'homepage', type: :feature, js: true do
  let!(:eu_store) { create(:store, default: true, supported_currencies: 'EUR', default_locale: 'de', supported_locales: 'de,fr') }
  let!(:us_store) { create(:store, supported_currencies: 'USD', default_locale: 'en', supported_locales: 'en') }

  context 'when no homepage is set' do
    before { visit spree.root_path }

    it 'the index page is still accesable with a back soon message' do
      expect(page).to have_text('We Will Be Back')
    end
  end

  context 'when homepage is set' do
    let!(:homepage) { create(:cms_homepage, store: eu_store, locale: 'de') }
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
    let!(:homepage_de) { create(:cms_homepage, store: eu_store, locale: 'de') }
    let!(:hp_section_de) { create(:cms_featured_article_section, cms_page: homepage_de) }

    before do
      I18n.locale = :fr
      Spree::Frontend::Config[:locale] = :fr

      hp_sec_de = Spree::CmsSection.find(hp_section_de.id)

      hp_sec_de.content[:title] = 'Hallo, das ist der Feature-Artikel auf der Homepage'
      hp_sec_de.save!
      hp_sec_de.reload

      visit spree.root_path
    end

    after do
      I18n.locale = :de
      Spree::Frontend::Config[:locale] = :de
    end

    it 'displays the cms_homepage for the stores default language' do
      expect(page).to have_text('Hallo, das ist der Feature-Artikel auf der Homepage')
    end
  end

  context 'when the index page is viewed using none default language and translation is present' do
    let!(:homepage_de) { create(:cms_homepage, store: eu_store, locale: 'de') }
    let!(:homepage_fr) { create(:cms_homepage, store: eu_store, locale: 'fr') }
    let!(:hp_section_de) { create(:cms_featured_article_section, cms_page: homepage_de) }
    let!(:hp_section_fr) { create(:cms_featured_article_section, cms_page: homepage_fr) }

    before do
      I18n.locale = :fr
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
      I18n.locale = :de
      Spree::Frontend::Config[:locale] = :de
    end

    it 'displays the correct cms_homepage' do
      expect(page).to have_text("Bonjour, c'est l'article vedette sur la page d'accueil")
    end
  end

  context 'homepage is displayed for the current store' do
    let!(:homepage_eu_store) { create(:cms_homepage, store: eu_store, locale: 'de') }
    let!(:homepage_us_store) { create(:cms_homepage, store: us_store, locale: 'en') }
    let!(:hp_section_de) { create(:cms_featured_article_section, cms_page: homepage_eu_store) }
    let!(:hp_section_us) { create(:cms_featured_article_section, cms_page: homepage_us_store) }

    before do
      eu_store.update(default: false)
      us_store.update(default: true)
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
      eu_store.update(default: true)
      us_store.update(default: false)
    end

    it 'displays the correct homepage for the current store' do
      expect(page).to have_text('Welcome To The US Store')
    end
  end
end
