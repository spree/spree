require 'spec_helper'

describe 'setting locale', type: :feature, js: true do
  let!(:store) { Spree::Store.default }
  let!(:locale) { :fr }

  let!(:en_main_menu) { create(:menu, name: 'Main Menu', store_id: store.id) }
  let!(:fr_main_menu) { create(:menu, name: 'Main Menu', locale: 'fr', store_id: store.id) }

  let!(:en_menu_item_url) { create(:menu_item, name: 'URL in English', menu_id: en_main_menu.id, destination: 'https://spree.com') }
  let!(:en_menu_item_home) { create(:menu_item, name: 'Home in English', menu_id: en_main_menu.id, linked_resource_type: 'Home Page') }
  let!(:en_menu_item_taxon) { create(:menu_item, name: 'Taxon in English', menu_id: en_main_menu.id, linked_resource_type: 'Spree::Taxon') }
  let!(:en_menu_item_product) { create(:menu_item, name: 'Product in English', menu_id: en_main_menu.id, linked_resource_type: 'Spree::Product') }

  let!(:fr_menu_item_url) { create(:menu_item, name: 'URL in French', menu_id: fr_main_menu.id, destination: 'https://spree.com') }
  let!(:fr_menu_item_home) { create(:menu_item, name: 'Home in French', menu_id: fr_main_menu.id, linked_resource_type: 'Home Page') }
  let!(:fr_menu_item_taxon) { create(:menu_item, name: 'Taxon in French', menu_id: fr_main_menu.id, linked_resource_type: 'Spree::Taxon') }
  let!(:fr_menu_item_product) { create(:menu_item, name: 'Product in French', menu_id: fr_main_menu.id, linked_resource_type: 'Spree::Product') }

  let!(:taxon_x) { create(:taxon) }
  let!(:prod_x) { create(:product_in_stock, taxons: [taxon_x]) }

  before do
    store.update(default_locale: 'en', supported_locales: 'en,fr')
    add_french_locales
    en_menu_item_taxon.update(linked_resource_id: taxon_x.id)
    en_menu_item_product.update(linked_resource_id: prod_x.id)

    fr_menu_item_taxon.update(linked_resource_id: taxon_x.id)
    fr_menu_item_product.update(linked_resource_id: prod_x.id)
  end

  context 'checkout form validation messages' do
    include_context 'checkout setup'

    let(:error_messages) do
      {
        'en' => 'This field is required.',
        'fr' => 'Ce champ est obligatoire.',
        'de' => 'Dieses Feld ist ein Pflichtfeld.'
      }
    end

    def check_error_text(text)
      %w(firstname lastname address1 city).each do |attr|
        expect(page).to have_css("#b#{attr} label.error", exact_text: text)
      end
    end
  end

  shared_examples 'translates cart page' do
    it 'is in french', retry: 3  do
      expect(page).to have_content('Votre panier')
      expect(page).to have_content('Votre panier est vide')
    end
  end

  shared_examples 'translates UI' do
    context 'locale dropdown' do
      before { open_i18n_menu }

      it { expect(page).to have_select('switch_to_locale', selected: 'Français (FR)') }
    end

    it { expect(page.evaluate_script('SPREE_LOCALE')).to eq('fr') }
  end

  shared_examples 'generates proper URLs' do
    it 'has localized links', retry: 3 do
      expect(page).to have_link(store.name, href: '/fr')
      expect(page).to have_link(fr_menu_item_taxon.name, href: spree.nested_taxons_path(fr_menu_item_taxon.linked_resource, locale: 'fr'))
      expect(page).to have_link(fr_menu_item_product.name, href: spree.product_path(fr_menu_item_product.linked_resource, locale: 'fr'))
    end
  end

  context 'with default store locale set' do
    before do
      store.update(default_locale: locale)
      visit spree.cart_path
    end

    after do
      store.update(default_locale: nil)
      I18n.locale = 'en'
    end

    it_behaves_like 'translates cart page'
    it_behaves_like 'translates UI'
  end

  context 'without store locale set' do
    before do
      I18n.locale = locale
      Spree::Frontend::Config[:locale] = locale
      visit spree.cart_path
    end

    after do
      I18n.locale = 'en'
      Spree::Frontend::Config[:locale] = 'en'
    end

    it_behaves_like 'translates cart page'
  end

  context 'locales list endpoint', js: false do
    before do
      visit spree.locales_path
    end

    it { expect(page).to have_http_status(:ok) }

    it 'renders the list' do
      expect(page).to have_text(Spree.t(:'i18n.language'))
      expect(page).to have_select('switch_to_locale', with_options: ['English (US)', 'Français (FR)'])
    end
  end

  context 'via UI' do
    before do
      visit spree.cart_path
      switch_to_locale('Français (FR)')
    end

    it { expect(page).to have_current_path('/fr/cart') }

    it_behaves_like 'translates UI'
    it_behaves_like 'translates cart page'
    it_behaves_like 'generates proper URLs'
  end

  context 'via URL' do
    let!(:taxon) { create(:taxon) }
    let!(:product) { create(:product_in_stock, taxons: [taxon]) }

    context 'cart page' do
      before do
        visit spree.cart_path(locale: 'fr')
      end

      it { expect(page).to have_current_path('/fr/cart') }

      it_behaves_like 'translates UI'
      it_behaves_like 'translates cart page'
      it_behaves_like 'generates proper URLs'
    end

    context 'products page' do
      before do
        visit spree.products_path(locale: 'fr')
      end

      it { expect(page).to have_current_path('/fr/products') }

      it_behaves_like 'translates UI'
      it_behaves_like 'generates proper URLs'

      it { expect(page).to have_link(product.name, href: spree.product_path(product, locale: 'fr')) }
    end

    context 'taxon page' do
      before do
        visit spree.nested_taxons_path(taxon, locale: 'fr')
      end

      it { expect(page).to have_current_path("/fr/t/#{taxon.permalink}") }

      it_behaves_like 'translates UI'
      it_behaves_like 'generates proper URLs'

      it { expect(page).to have_link(product.name, href: spree.product_path(product, locale: 'fr', taxon_id: taxon.id)) }
    end

    context 'product page' do
      before do
        visit spree.product_path(product, locale: 'fr')
      end

      it { expect(page).to have_current_path("/fr/products/#{product.slug}") }

      it_behaves_like 'translates UI'
      it_behaves_like 'generates proper URLs'

      it { expect(page).to have_link(taxon.name, href: spree.nested_taxons_path(taxon, locale: 'fr')) }
    end

    context 'home page' do
      before do
        visit spree.root_path(locale: 'fr')
      end

      it { expect(page).to have_current_path('/fr') }

      it_behaves_like 'translates UI'
      it_behaves_like 'generates proper URLs'
    end

    context 'not supported locale' do
      context 'home page' do
        before do
          visit spree.root_path(locale: 'es')
        end

        it { expect(page).to have_current_path('/') }
      end

      context 'product page' do
        before do
          visit spree.product_path(product, locale: 'es')
        end

        it { expect(page).to have_current_path(spree.product_path(product)) }
      end
    end
  end
end
