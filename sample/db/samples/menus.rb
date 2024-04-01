Spree::Store.all.each do |store|
  store.supported_locales_list.each do |locale|
    case locale
    when 'uk'
      Spree::Menu.where(
        name: 'Головне меню',
        location: 'header',
        store_id: store,
        locale: locale
      ).first_or_create!

      Spree::Menu.where(
        name: 'Нижнє меню',
        location: 'footer',
        store_id: store,
        locale: locale
      ).first_or_create!
    else
      Spree::Menu.where(
        name: 'Main Menu',
        location: 'header',
        store_id: store,
        locale: locale
      ).first_or_create!

      Spree::Menu.where(
        name: 'Footer Menu',
        location: 'footer',
        store_id: store,
        locale: locale
      ).first_or_create!
    end
  end
end
