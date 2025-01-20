FactoryBot.define do
  factory :custom_domain, class: Spree::CustomDomain do
    url { FFaker::Internet.domain_name }
    store { create(:store) }
    default { true }
  end
end
