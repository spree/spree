require 'spec_helper'

describe 'setting locale', type: :feature, js: true do
  let!(:store) { Spree::Store.default }
  let!(:locale) { :fr }

  let!(:main_menu) { create(:menu, name: 'Main Menu', unique_code: 'spree-all-main', store_id: store.id) }

  let!(:mi_root) { create(:menu_item, name: 'URL', menu_id: main_menu.id, parent_id: main_menu.root.id, destination: 'https://spree.com') }
  let!(:mi_home) { create(:menu_item, name: 'Home', menu_id: main_menu.id, parent_id: main_menu.root.id, linked_resource_type: 'Home Page') }
  let!(:mi_ta) { create(:menu_item, name: 'Taxon', menu_id: main_menu.id, parent_id: main_menu.root.id, linked_resource_type: 'Spree::Taxon') }
  let!(:mi_pro) { create(:menu_item, name: 'Product', menu_id: main_menu.id, parent_id: main_menu.root.id, linked_resource_type: 'Spree::Product') }

  let!(:tax_x) { create(:taxon) }
  let!(:pr_x) { create(:product_in_stock, taxons: [tax_x]) }

  before do
    store.update(default_locale: 'en', supported_locales: 'en,fr')
    add_french_locales
    mi_ta.update(linked_resource_id: tax_x.id)
    mi_pro.update(linked_resource_id: pr_x.id)
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
      expect(page).to have_link(mi_ta.name, href: spree.nested_taxons_path(mi_ta.linked_resource, locale: 'fr'))
      expect(page).to have_link(mi_pro.name, href: spree.product_path(mi_pro.linked_resource, locale: 'fr'))
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
