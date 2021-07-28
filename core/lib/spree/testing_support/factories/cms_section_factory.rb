FactoryBot.define do
  factory :cms_section, class: Spree::CmsSection do
    association :cms_page, factory: :cms_standard_page

    name { generate(:random_string) }

    factory :cms_hero_image_section do
      type { 'Spree::Cms::Sections::HeroImage' }
    end

    factory :cms_featured_article_section do
      type { 'Spree::Cms::Sections::FeaturedArticle' }
    end

    factory :cms_product_carousel_section do
      type { 'Spree::Cms::Sections::ProductCarousel' }
    end

    factory :cms_image_gallery_section do
      type { 'Spree::Cms::Sections::ImageGallery' }
    end

    factory :cms_side_by_side_images_section do
      type { 'Spree::Cms::Sections::SideBySideImages' }
    end

    factory :cms_rich_text_content_section do
      type { 'Spree::Cms::Sections::RichTextContent' }
    end

    trait :with_cms_page do
      before(:create) do
      end
    end
  end
end
