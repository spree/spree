PAGES = []

Spree::CmsPage.all.each do |page|
  unless page.type == 'Spree::Cms::Pages::StandardPage'
    PAGES << page
  end
end

# Hero Image
PAGES.each do |page|
  case page.locale
  when 'en'
    name_txt = 'Hero Image'
    title_txt = 'Summer Collection'
    button_txt = 'Shop Now'
  when 'de'
    name_txt = 'Heldenbild'
    title_txt = 'Sommerkollektion'
    button_txt = 'Jetzt einkaufen'
  when 'fr'
    name_txt = 'Image de héros'
    title_txt = "Collection d'été"
    button_txt = 'Achetez maintenant'
  when 'es'
    name_txt = 'Imagen de héroe'
    title_txt = 'Colección de verano'
    button_txt = 'Compra ahora'
  end

  summer_collection = Spree::Taxon.find_by!(permalink: "categories/new-collection/summer-#{Date.today.year}")

  hero_section = Spree::CmsSection.where(
    name: name_txt,
    type: 'Spree::Cms::Sections::HeroImage',
    linked_resource_type: 'Spree::Taxon',
    cms_page: page
  ).first_or_create!

  hero_section.title = title_txt
  hero_section.button_text = button_txt
  hero_section.linked_resource_id = summer_collection.id
  hero_section.save!
end

# Three Taxons
PAGES.each do |page|
  link_one = 'categories/men'
  link_two = 'categories/women'
  link_three = 'categories/sportswear'

  case page.locale
  when 'en'
    name_txt = 'Main Taxons'

    title_one = 'Men'
    title_two = 'Women'
    title_three = 'Sportswear'

  when 'de'
    name_txt = 'Haupttaxa'

    title_one = 'Männer'
    title_two = 'Frauen'
    title_three = 'Sportbekleidung'
  when 'fr'
    name_txt = 'Main Taxons'

    title_one = 'Hommes'
    title_two = 'Femmes'
    title_three = 'Tenue de sport'
  when 'es'
    name_txt = 'Taxón principal'

    title_one = 'Hombres'
    title_two = 'Mujeres'
    title_three = 'Ropa de deporte'
  end

  three_taxon_section = Spree::CmsSection.where(
    name: name_txt,
    type: 'Spree::Cms::Sections::ImageGallery',
    cms_page: page
  ).first_or_create!

  three_taxon_section.link_one = link_one
  three_taxon_section.link_two = link_two
  three_taxon_section.link_three = link_three

  three_taxon_section.title_one = title_one
  three_taxon_section.title_two = title_two
  three_taxon_section.title_three = title_three

  three_taxon_section.save!
end

# Best Sellers Product Carousel
PAGES.each do |page|
  case page.locale
  when 'en'
    name_txt = 'Best Sellers Carousel'
  when 'de'
    name_txt = 'Bestseller Karussell'
  when 'fr'
    name_txt = 'Carrousel des meilleures ventes'
  when 'es'
    name_txt = 'Carrusel de los más vendidos'
  end

  bestsellers = Spree::Taxon.find_by!(permalink: 'categories/bestsellers')

  product_carousel = Spree::CmsSection.where(
    name: name_txt,
    type: 'Spree::Cms::Sections::ProductCarousel',
    linked_resource_type: 'Spree::Taxon',
    cms_page: page
  ).first_or_create!

  product_carousel.linked_resource_id = bestsellers.id
  product_carousel.save!
end

# Featured Article
PAGES.each do |page|
  case page.locale
  when 'en'
    name_txt = 'Fashion Trends'
    title_txt = "Summer #{Date.today.year}"
    subtitle_txt = 'Fashion Trends'
    button_txt = 'Read More'
  when 'de'
    name_txt = 'Modetrends'
    title_txt = "Sommer #{Date.today.year}"
    subtitle_txt = 'Modetrends'
    button_txt = 'Weiterlesen'
  when 'fr'
    name_txt = 'Tendances de la mode'
    title_txt = "Été #{Date.today.year}"
    subtitle_txt = 'Tendances de la mode'
    button_txt = 'Lire la suite'
  when 'es'
    name_txt = 'Tendencias de la moda'
    title_txt = "Verano #{Date.today.year}"
    subtitle_txt = 'Tendencias de la moda'
    button_txt = 'Lee mas'
  end

  trending = Spree::Taxon.find_by!(permalink: 'categories/trending')

  featured_article = Spree::CmsSection.where(
    name: name_txt,
    type: 'Spree::Cms::Sections::FeaturedArticle',
    linked_resource_type: 'Spree::Taxon',
    cms_page: page
  ).first_or_create!

  featured_article.title = title_txt
  featured_article.subtitle = subtitle_txt
  featured_article.button_text = button_txt
  featured_article.rte_content = '<div style="text-center">Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam.</div>'
  featured_article.linked_resource_id = trending.id
  featured_article.save!
end

# Trending Product Carousel
PAGES.each do |page|
  case page.locale
  when 'en'
    name_txt = 'Trending Carousel'
  when 'de'
    name_txt = 'Trendiges Karussell'
  when 'fr'
    name_txt = 'Carrousel tendance'
  when 'es'
    name_txt = 'Carrusel de tendencias'
  end

  trending = Spree::Taxon.find_by!(permalink: 'categories/trending')

  trending_section = Spree::CmsSection.where(
    name: name_txt,
    type: 'Spree::Cms::Sections::ProductCarousel',
    linked_resource_type: 'Spree::Taxon',
    cms_page: page
  ).first_or_create!

  trending_section.linked_resource_id = trending.id
  trending_section.save!
end

# Side-by-Side Promotions
PAGES.each do |page|
  link_one = 'categories/streetstyle'
  link_two = 'categories/special-offers/30-percent-off'

  case page.locale
  when 'en'
    name_txt = 'Promotions'

    title_one = 'New Collection'
    subtitle_one = 'Street Style'

    title_two = 'Summer Sale'
    subtitle_two = 'Up To 30% OFF'

  when 'de'
    name_txt = 'Werbeaktionen'

    title_one = 'Neue Kollektion'
    subtitle_one = 'Street Style'

    title_two = 'Summer Sale'
    subtitle_two = 'Bis zu 30% RABATT'
  when 'fr'
    name_txt = 'Promotions'

    title_one = 'Nouvelle collection'
    subtitle_one = 'Style de rue'

    title_two = 'Summer Sale'
    subtitle_two = "Jusqu'à 30% de réduction"
  when 'es'
    name_txt = 'Promociones'

    title_one = 'Nueva colección'
    subtitle_one = 'Estilo callejero'

    title_two = 'Summer Sale'
    subtitle_two = 'Hasta 30% DE DESCUENTO'
  end

  promos_section = Spree::CmsSection.where(
    name: name_txt,
    type: 'Spree::Cms::Sections::SideBySideImages',
    cms_page: page
  ).first_or_create!

  promos_section.title_one = title_one
  promos_section.subtitle_one = subtitle_one
  promos_section.link_one = link_one

  promos_section.title_two = title_two
  promos_section.subtitle_two = subtitle_two
  promos_section.link_two = link_two

  promos_section.save!
end
