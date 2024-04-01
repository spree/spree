PAGES = []

Spree::CmsPage.all.each do |page|
  unless page.type == 'Spree::Cms::Pages::StandardPage'
    PAGES << page
  end
end

def image(filename, image_type)
  picture = case image_type
  when "one"
    Spree::CmsSectionImageOne.new
  when "two"
    Spree::CmsSectionImageTwo.new
  when "three"
    Spree::CmsSectionImageThree.new
  end

  file = File.open(File.join(__dir__, "images", "cms_sections", filename + ".jpg"))
  picture.attachment.attach(io: file, filename:, content_type: 'image/jpg')
  picture
end

# Hero Image
PAGES.each do |page|
  case page.locale
  when 'en'
    name_txt = 'Hero Image'
    title_txt = 'Summer Collection'
    button_txt = 'Shop Now'
  when 'uk'
    name_txt = 'Головне зображення'
    title_txt = 'Літня Колекція'
    button_txt = 'Купити Зараз'
  end

  summer_collection = Spree::Taxon.find_by(permalink: "katieghoriyi/nova-koliektsiia/lito-#{Date.today.year}")

  hero_section = Spree::CmsSection.where(
    name: name_txt,
    type: 'Spree::Cms::Sections::HeroImage',
    linked_resource_type: 'Spree::Taxon',
    cms_page: page
  ).first_or_create!

  hero_section.title = title_txt
  hero_section.button_text = button_txt
  hero_section.linked_resource_id = summer_collection.id
  hero_section.image_one = image("summer_collection", "one")
  hero_section.save!
end

# Three Taxons
PAGES.each do |page|  
  link_one = 'katieghoriyi/choloviki'
  link_two = 'katieghoriyi/zhinki'
  link_three = 'katieghoriyi/sportivnii-odiagh'
  case page.locale
  when 'en'
    name_txt = 'Main Taxons'

    title_one = 'Men'
    title_two = 'Women'
    title_three = 'Sportswear'
  when 'uk'
    name_txt = 'Основні таксони'

    title_one = 'Чоловіки'
    title_two = 'Жінки'
    title_three = 'Спортивний одяг'
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

  three_taxon_section.image_one = image("first_left", "one")
  three_taxon_section.image_two = image("right", "two")
  three_taxon_section.image_three = image("second_left", "three")

  three_taxon_section.save!
end

# Best Sellers Product Carousel
PAGES.each do |page|
  case page.locale
  when 'en'
    name_txt = 'Best Sellers Carousel'
  when 'uk'
    name_txt = 'Карусель кращих продавців'
  end

  bestsellers = Spree::Taxon.find_by!(permalink: 'katieghoriyi/biestsiellieri')

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
  when 'uk'
    name_txt = 'Модні Тенденції'
    title_txt = "Літо #{Date.today.year}"
    subtitle_txt = 'Модні Тенденції'
    button_txt = 'Детальніше'
  end

  trending = Spree::Taxon.find_by!(permalink: 'katieghoriyi/v-triendakh')

  featured_article = Spree::CmsSection.where(
    name: name_txt,
    type: 'Spree::Cms::Sections::FeaturedArticle',
    linked_resource_type: 'Spree::Taxon',
    cms_page: page
  ).first_or_create!

  featured_article.title = title_txt
  featured_article.subtitle = subtitle_txt
  featured_article.button_text = button_txt
  featured_article.rte_content = '<div style="text-center">Важливо доглядати за хворим, слідкувати за хворим, але це станеться в такий час, коли буде багато роботи і болю. З роками прийду.</div>'
  featured_article.linked_resource_id = trending.id
  featured_article.save!
end

# Trending Product Carousel
PAGES.each do |page|
  case page.locale
  when 'en'
    name_txt = 'Trending Carousel'
  when 'uk'
    name_txt = 'Карусель трендів'
  end

  trending = Spree::Taxon.find_by!(permalink: 'katieghoriyi/v-triendakh')

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
  link_one = 'katieghoriyi/vulichnii-stil'
  link_two = 'katieghoriyi/spietsialni-propozitsiyi/znizhka-30-percent'
  case page.locale
  when 'en'
    name_txt = 'Promotions'

    title_one = 'New Collection'
    subtitle_one = 'Street Style'

    title_two = 'Summer Sale'
    subtitle_two = 'Up To 30% OFF'
  when 'uk'
    name_txt = 'Акції'

    title_one = 'Нова Колекція'
    subtitle_one = 'Вуличний Стиль'

    title_two = 'Літній Розпродаж'
    subtitle_two = 'ЗНИЖКИ до 30%'
  end

  promos_section = Spree::CmsSection.where(
    name: name_txt,
    type: 'Spree::Cms::Sections::SideBySideImages',
    cms_page: page
  ).first_or_create!

  promos_section.title_one = title_one
  promos_section.subtitle_one = subtitle_one
  promos_section.link_one = link_one
  promos_section.image_one = image("street_style", "one")

  promos_section.title_two = title_two
  promos_section.subtitle_two = subtitle_two
  promos_section.link_two = link_two
  promos_section.image_two = image("for_sale", "two")

  promos_section.save!
end
