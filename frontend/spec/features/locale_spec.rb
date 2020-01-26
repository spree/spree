require 'spec_helper'

describe 'setting locale', type: :feature do
  def with_locale(locale)
    I18n.locale = locale
    Spree::Frontend::Config[:locale] = locale
    yield
    I18n.locale = 'en'
    Spree::Frontend::Config[:locale] = 'en'
  end

  context 'cart page' do
    before do
      I18n.backend.store_translations(:fr,
                                      spree: {
                                        cart_page: {
                                          header: 'Votre panier',
                                          empty_info: 'Votre panier est vide'
                                        }
                                      })
    end

    it 'is in french' do
      with_locale('fr') do
        visit spree.cart_path
        expect(page).to have_content('Votre panier')
        expect(page).to have_content('Votre panier est vide')
      end
    end
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
end
