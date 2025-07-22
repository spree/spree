require "spec_helper"

RSpec.describe "Stores translations", type: :feature, js: true do
  stub_authorization!

  let(:store) do
    create(:store,
      name: "Store", description: "Store",
      meta_description: "Store",
      seo_title: "Store",
      facebook: "https://facebook.com/store",
      twitter: "https://x.com/store",
      instagram: "https://instagram.com/store",
      customer_support_email: "store@example.com",
      address: "Store 123, 00-000 Store",
      contact_phone: "123 456 789"
    )
  end

  before do
    allow_any_instance_of(Spree::Admin::BaseController).to receive(:current_store).and_return(store)

    I18n.backend.store_translations(:fr,
      spree: {
        i18n: {
          language: 'Langue',
          this_file_language: 'Français (FR)'
        },
      }
    )

    visit spree.edit_admin_store_path(store, section: "general-settings")

    within('#page_actions_dropdown') do
      click_on 'more-actions-link'
      click_on Spree.t(:translations)
    end
  end

  context 'when there is only one language' do
    it 'shows message to add more languages' do
      expect(page).to have_content('To use translations, configure more than one locale for the store.')
    end
  end

  context 'when there are 2 languages' do
    let(:store) do
      create(:store,
        name: "Store", description: "Store",
        meta_description: "Store",
        seo_title: "Store",
        facebook: "https://facebook.com/store",
        twitter: "https://x.com/store",
        instagram: "https://instagram.com/store",
        customer_support_email: "store@example.com",
        address: "Store 123, 00-000 Store",
        contact_phone: "123 456 789",
        supported_locales: 'en,pl'
      )
    end

    it "allows to translate store" do
      expect(page).to have_field('store_name_pl')

      fill_in :store_name_pl, with: 'Sklep'
      fill_in :store_meta_description_pl, with: 'Sklep'
      fill_in :store_seo_title_pl, with: 'Sklep'
      fill_in :store_facebook_pl, with: 'https://facebook.com/sklep'
      fill_in :store_twitter_pl, with: 'https://x.com/sklep'
      fill_in :store_instagram_pl, with: 'https://instagram.com/sklep'
      fill_in :store_customer_support_email_pl, with: 'sklep@example.com'
      fill_in :store_address_pl, with: 'ul. Sklep 123, 00-000 Sklep'
      fill_in :store_contact_phone_pl, with: '123 456 789'

      click_on Spree.t(:update)

      expect(page).to have_content('Translations successfully saved')

      I18n.with_locale(:en) do
        expect(store.reload.name).to eq('Store')
        expect(store.meta_description).to eq('Store')
        expect(store.seo_title).to eq('Store')
        expect(store.facebook).to eq('https://facebook.com/store')
        expect(store.twitter).to eq('https://x.com/store')
        expect(store.instagram).to eq('https://instagram.com/store')
        expect(store.customer_support_email).to eq('store@example.com')
        expect(store.address).to eq('Store 123, 00-000 Store')
        expect(store.contact_phone).to eq('123 456 789')
      end

      I18n.with_locale(:pl) do
        expect(store.reload.name).to eq('Sklep')
        expect(store.meta_description).to eq('Sklep')
        expect(store.seo_title).to eq('Sklep')
        expect(store.facebook).to eq('https://facebook.com/sklep')
        expect(store.twitter).to eq('https://x.com/sklep')
        expect(store.instagram).to eq('https://instagram.com/sklep')
        expect(store.customer_support_email).to eq('sklep@example.com')
        expect(store.address).to eq('ul. Sklep 123, 00-000 Sklep')
        expect(store.contact_phone).to eq('123 456 789')
      end
    end
  end

  context 'when there are more languages' do
    let(:store) do
      create(:store,
        name: "Store", description: "Store",
        meta_description: "Store",
        seo_title: "Store",
        facebook: "https://facebook.com/store",
        twitter: "https://x.com/store",
        instagram: "https://instagram.com/store",
        customer_support_email: "store@example.com",
        address: "Store 123, 00-000 Store",
        contact_phone: "123 456 789",
        supported_locales: 'en,de,fr'
      )
    end

    it 'shows dropdown to select language' do
      expect(page).to have_select('translation_locale')
      select "Français (FR)", from: 'translation_locale'

      expect(page).to have_field('store_name_fr')

      fill_in :store_name_fr, with: 'Magasin'
      fill_in :store_meta_description_fr, with: 'Magasin'
      fill_in :store_seo_title_fr, with: 'Magasin'
      fill_in :store_facebook_fr, with: 'https://facebook.com/magasin'
      fill_in :store_twitter_fr, with: 'https://x.com/magasin'
      fill_in :store_instagram_fr, with: 'https://instagram.com/magasin'
      fill_in :store_customer_support_email_fr, with: 'magasin@example.com'
      fill_in :store_address_fr, with: 'Magasin 123, 00-000 Magasin'
      fill_in :store_contact_phone_fr, with: '123 456 789'

      click_on Spree.t(:update)
      expect(page).to have_content('Translations successfully saved')

      I18n.with_locale(:fr) do
        expect(store.reload.name).to eq('Magasin')
        expect(store.meta_description).to eq('Magasin')
        expect(store.seo_title).to eq('Magasin')
        expect(store.facebook).to eq('https://facebook.com/magasin')
        expect(store.twitter).to eq('https://x.com/magasin')
        expect(store.instagram).to eq('https://instagram.com/magasin')
        expect(store.customer_support_email).to eq('magasin@example.com')
        expect(store.address).to eq('Magasin 123, 00-000 Magasin')
        expect(store.contact_phone).to eq('123 456 789')
      end
    end
  end
end
