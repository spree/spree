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
end
