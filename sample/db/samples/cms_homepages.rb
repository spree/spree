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
    when 'uk'
      Spree::CmsPage.where(
        title: "Головна сторінка (Українська)",
        type: 'Spree::Cms::Pages::Homepage',
        store: store,
        locale: locale
      ).first_or_create!
    end
  end
end
