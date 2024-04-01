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
    when 'uk'
      Spree::CmsPage.where(
        title: 'Сторінка функцій',
        type: 'Spree::Cms::Pages::FeaturePage',
        store: store,
        locale: locale
      ).first_or_create!
    end
  end
end
