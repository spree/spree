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
