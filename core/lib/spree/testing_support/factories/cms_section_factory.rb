FactoryBot.define do
  factory :cms_section, class: Spree::CmsSection do
    name { generate(:random_string) }

    factory :cms_hero_section do
      type { 'Spree::Cms::Sections::FullScreenHeroImage' }
    end

    factory :cms_featured_article_section do
      type { 'Spree::Cms::Sections::FeaturedArticle' }
    end

    factory :cms_product_carousel_section do
      type { 'Spree::Cms::Sections::ProductCarousel' }
    end

    factory :cms_three_taxon_categories_section do
      type { 'Spree::Cms::Sections::ThreeTaxonCategoriesBlock' }
    end

    factory :cms_static_branding_bar_section do
      type { 'Spree::Cms::Sections::StaticBrandingBar' }
    end

    factory :cms_side_by_side_promotion_section do
      type { 'Spree::Cms::Sections::SideBySidePromotion' }
    end
  end
end
