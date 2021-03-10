module Spree
  module TestingSupport
    module LocaleHelpers
      def open_i18n_menu
        find('#header #internationalization-button-desktop').click
        expect(page).to have_selector('#internationalization-options-desktop')
      end

      def close_i18n_menu
        find('#header #internationalization-button-desktop').click
        expect(page).not_to have_selector('#internationalization-options-desktop')
      end

      def switch_to_currency(currency)
        open_i18n_menu
        select currency, from: 'switch_to_currency'
        expect(page).to have_no_css '.turbolinks-progress-bar'
      end

      def switch_to_locale(locale)
        open_i18n_menu
        select locale, from: 'Language'
      end
    end
  end
end
