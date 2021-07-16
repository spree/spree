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
    when 'fr'
      Spree::CmsPage.where(
        title: 'À propos de nous',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Politique de confidentialité',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: "Politique d'expédition",
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Politique de retour',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!
    when 'de'
      Spree::CmsPage.where(
        title: 'Über uns',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Datenschutz-Bestimmungen',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Versandbedingungen',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Rückgaberecht',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!
    when 'es'
      Spree::CmsPage.where(
        title: 'Sobre nosotros',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Política de privacidad',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Politica de envios',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!

      Spree::CmsPage.where(
        title: 'Política de devoluciones',
        type: 'Spree::Cms::Pages::StandardPage',
        store: store,
        locale: locale,
        content: FFaker::Lorem.paragraph(8)
      ).first_or_create!
    end
  end
end
