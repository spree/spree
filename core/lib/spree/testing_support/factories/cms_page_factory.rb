FactoryBot.define do
  factory :base_cms_page, class: Spree::CmsPage do
    title { generate(:random_string) }
    locale { 'en' }

    store

    factory :cms_homepage do
      type { 'Spree::Cms::Pages::Homepage' }
    end

    factory :cms_standard_page do
      type { 'Spree::Cms::Pages::StandardPage' }
    end

    factory :cms_feature_page do
      type { 'Spree::Cms::Pages::FeaturePage' }
    end
  end
end
