FactoryBot.define do
  factory :cms_page, class: Spree::CmsPage do
    title { generate(:random_string) }
    locale { 'en' }
  end
end
