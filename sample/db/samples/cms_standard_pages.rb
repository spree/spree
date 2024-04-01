Spree::Store.all.each do |store|
  store.supported_locales_list.each do |locale|
    case locale
    when 'en'
      Spree::CmsPage.where(
        title: 'About Us',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Privacy Policy',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Shipping Policy',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Returns Policy',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!
    when 'uk'
      Spree::CmsPage.where(
        title: 'Про нас',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::LoremUA.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Політика конфіденційності',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::LoremUA.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Політика доставки',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::LoremUA.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Політика повернення товару',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::LoremUA.paragraph(8)
      ).first_or_create!
    end
  end
end
