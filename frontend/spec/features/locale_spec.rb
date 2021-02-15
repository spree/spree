require 'spec_helper'

describe 'setting locale', type: :feature do
  let(:store) { Spree::Store.default }
  let(:locale) { :fr }

  before do
    I18n.backend.store_translations(:fr,
                                    spree: {
                                      added_to_cart: 'Ajouté au panier avec succès!',
                                      cart_page: {
                                        header: 'Votre panier',
                                        empty_info: 'Votre panier est vide'
                                      },
                                      i18n: {
                                        this_file_language: 'Français (FR)'
                                      }
                                    })
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
    it 'is in french' do
      visit spree.cart_path
      expect(page).to have_content('Votre panier')
      expect(page).to have_content('Votre panier est vide')
    end
  end

  context 'with store locale set' do
    before do
      store.update(default_locale: locale)
    end

    after do
      store.update(default_locale: nil)
      I18n.locale = 'en'
    end

    it_behaves_like 'translates cart page'
  end

  context 'without store locale set' do
    before do
      I18n.locale = locale
      Spree::Frontend::Config[:locale] = locale
    end

    after do
      I18n.locale = 'en'
      Spree::Frontend::Config[:locale] = 'en'
    end

    it_behaves_like 'translates cart page'
  end

  context 'via set_locale endpoint' do
    before do
      store.update(default_locale: 'en', supported_locales: 'en,fr')
      visit spree.set_locale_path(switch_to_locale: 'fr')
    end

    after do
      I18n.locale = 'en'
    end

    it_behaves_like 'translates cart page'
  end

  context 'locales list endpoint' do
    before do
      store.update(default_locale: 'en', supported_locales: 'en,fr')
      visit spree.locales_path
    end

    it { expect(page).to have_http_status(:ok) }

    it 'renders the list' do
      expect(page).to have_text(Spree.t(:'i18n.language'))
      expect(page).to have_select('switch_to_locale', with_options: ['English (US)', 'Français (FR)'])
    end
  end

  context 'via UI', :js do
    before do
      store.update(default_locale: 'en', supported_locales: 'en,fr')
      visit spree.cart_path
      switch_to_locale('Français (FR)')
    end

    it_behaves_like 'translates cart page'
  end
end
