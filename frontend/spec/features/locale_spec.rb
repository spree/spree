require 'spec_helper'

describe 'setting locale', type: :feature do
  def with_locale(locale)
    I18n.locale = locale
    Spree::Frontend::Config[:locale] = locale
    yield
    I18n.locale = 'en'
    Spree::Frontend::Config[:locale] = 'en'
  end

  context 'shopping cart link and page' do
    before do
      I18n.backend.store_translations(:fr,
                                      spree: {
                                        cart: 'Panier',
                                        shopping_cart: 'Panier'
                                      })
    end

    it 'is in french' do
      with_locale('fr') do
        visit spree.root_path
        click_link 'Panier'
        expect(page).to have_content('Panier')
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
