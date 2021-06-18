FactoryBot.define do
  factory :base_cms_page, class: Spree::CmsPage do
    title { generate(:random_string) }
    locale { 'en' }

    factory :cms_homepage, class: Spree::CmsPage do
      type { 'Spree::Cms::Pages::Homepage' }
    end

    factory :cms_standard_page, class: Spree::CmsPage do
      type { 'Spree::Cms::Pages::StandardPage' }
    end

    factory :cms_feature_page, class: Spree::CmsPage do
      type { 'Spree::Cms::Pages::FeaturePage' }
    end
  end
end
