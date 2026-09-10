FactoryBot.define do
  factory :supplier, class: Spree::Supplier do
    store { Spree::Store.default || create(:store) }
    sequence(:name) { |n| "Supplier ##{n}" }
    contact_name { 'Dana Okafor' }
    sequence(:email) { |n| "supplier#{n}@example.com" }
    phone { '555-0100' }

    trait :with_address do
      address1 { '1 Warehouse Way' }
      city { 'Brooklyn' }
      state_code { 'NY' }
      country_code { 'US' }
      postal_code { '11201' }
    end
  end
end
