FactoryBot.define do
  factory :market, class: Spree::Market do
    sequence(:name) { |n| "Market #{n}" }
    currency { 'USD' }
    default_locale { 'en' }
    store
    countries { [association(:country)] }

    trait :default do
      default { true }
    end

    trait :eu do
      name { 'Europe' }
      currency { 'EUR' }
      default_locale { 'de' }
      tax_inclusive { true }
    end
  end
end
