Spree::Store.all.each do |store|
  store.supported_locales_list.each do |locale|
    main_menu_attrs = {
      name: 'Main Menu',
      location: 'header',
      store: store,
      locale: locale
    }
    footer_menu_attrs = {
      name: 'Footer Menu',
      location: 'footer',
      store: store,
      locale: locale
    }

    if Spree::Menu.where(main_menu_attrs).any?
      Spree::Menu.where(main_menu_attrs).first
    else
      Spree::Menu.create!(main_menu_attrs)
    end

    if Spree::Menu.where(footer_menu_attrs).any?
      Spree::Menu.where(footer_menu_attrs).first
    else
      Spree::Menu.create!(footer_menu_attrs)
    end
  end
end
