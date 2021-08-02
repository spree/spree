Spree::Store.all.each do |store|
  store.supported_locales_list.each do |locale|
    case locale
    when 'en'
      Spree::CmsPage.where(
        title: 'Homepage (English)',
        type: 'Spree::Cms::Pages::Homepage',
        store: store,
        locale: locale
      ).first_or_create!
    when 'fr'
      Spree::CmsPage.where(
        title: "Page d'accueil (Français)",
        type: 'Spree::Cms::Pages::Homepage',
        store: store,
        locale: locale
      ).first_or_create!
    when 'de'
      Spree::CmsPage.where(
        title: 'Startseite (Deutsche)',
        type: 'Spree::Cms::Pages::Homepage',
        store: store,
        locale: locale
      ).first_or_create!
    when 'es'
      Spree::CmsPage.where(
        title: 'Página principal (Español)',
        type: 'Spree::Cms::Pages::Homepage',
        store: store,
        locale: locale
      ).first_or_create!
    end
  end
end
