module Spree
  module TestingSupport
    module LocaleHelpers
      # rubocop:disable Layout/ArgumentAlignment
      def add_french_locales
        I18n.backend.store_translations(:fr,
          spree: {
            added_to_cart: 'Ajouté au panier avec succès!',
            continue_shopping: 'Continuer vos achats',
            choose_currency: 'Choisir la devise',
            internationalization: 'Internationalisation',
            i18n: {
              language: 'Langue',
              this_file_language: 'Français (FR)'
            },
            cart_page: {
              header: 'Votre panier',
              empty_info: 'Votre panier est vide',
              add_promo_code: 'AJOUTER UN CODE PROMOTIONNEL',
              checkout: 'Passer la commande',
              product: 'articles',
              quantity: 'quantité',
              title: 'Panier',
              change_quantity: 'Changer la quantité',
              remove_from_cart: 'Retirer du panier'
            },
            shopping_cart: 'Panier',
            cart: 'Panier',
            close: 'Fermer',
            search: 'Rechercher',
            home: 'Accueil',
            nav_bar: {
              admin_panel: "Panneau d'administration",
              close_menu: 'Fermer le menu',
              go_to_previous_menu: 'Vers le menu précédent',
              show_menu: 'Afficher le menu',
              show_search: 'Afficher la recherche',
              show_user_menu: 'Afficher le menu utilisateur',
              change_country: 'Changer de pays',
              desktop: 'Navigation sur le bureau',
              mobile: 'Navigation mobile'
            },
            login: 'Connexion',
            logout: 'Se déconnecter',
            sign_up: 'Enregistrer',
            email: 'Courriel',
            password: 'Mot de passe',
            remember_me: 'Se souvenir de moi',
            my_account: 'Mon compte',
            my_orders: 'Mes commandes',
            logged_in_succesfully: 'Connexion réussie'
          })
      end
      # rubocop:enable Layout/ArgumentAlignment

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
