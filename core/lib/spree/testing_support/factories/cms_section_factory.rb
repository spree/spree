FactoryBot.define do
  factory :cms_section, class: Spree::CmsSection do
    name { generate(:random_string) }
  end
end
