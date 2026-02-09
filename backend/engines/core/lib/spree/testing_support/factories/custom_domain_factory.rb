FactoryBot.define do
  factory :custom_domain, class: Spree::CustomDomain do
    url { FFaker::Internet.domain_name }
    association :store, factory: :store
    default { true }
  end
end
