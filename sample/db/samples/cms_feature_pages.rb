Spree::Store.all.each do |store|
  store.supported_locales_list.each do |locale|
    case locale
    when 'en'
      Spree::CmsPage.where(
        title: 'Feature Page',
        type: 'Spree::Cms::Pages::FeaturePage',
        store: store,
        locale: locale
      ).first_or_create!
    when 'fr'
      Spree::CmsPage.where(
        title: 'Page de fonctionnalité',
        type: 'Spree::Cms::Pages::FeaturePage',
        store: store,
        locale: locale
      ).first_or_create!
    when 'de'
      Spree::CmsPage.where(
        title: 'Feature-Seite',
        type: 'Spree::Cms::Pages::FeaturePage',
        store: store,
        locale: locale
      ).first_or_create!
    when 'es'
      Spree::CmsPage.where(
        title: 'Página de características',
        type: 'Spree::Cms::Pages::FeaturePage',
        store: store,
        locale: locale
      ).first_or_create!
    end
  end
end
