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
        log_in: 'SE CONNECTER',
        log_out: 'DÉCONNEXION',
        my_account: 'MON COMPTE',
        my_orders: 'MES COMMANDES',
        show_menu: 'Afficher le menu',
        show_search: 'Afficher la recherche',
        show_user_menu: 'Afficher le menu utilisateur',
        sign_up: 'ENREGISTRER',
        change_country: 'Changer de pays',
        desktop: 'Navigation sur le bureau',
        mobile: 'Navigation mobile'
      }
    })
end

def open_i18n_menu
  find('#header #internationalization-button-desktop').click
end

def switch_to_currency(currency)
  open_i18n_menu
  select currency, from: 'switch_to_currency'
end

def switch_to_locale(locale)
  open_i18n_menu
  select locale, from: 'Language'
end
