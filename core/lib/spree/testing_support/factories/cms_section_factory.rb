FactoryBot.define do
  factory :base_cms_section, class: Spree::CmsSection do
    name { generate(:random_string) }

    factory :cms_section do
    end
  end
end
