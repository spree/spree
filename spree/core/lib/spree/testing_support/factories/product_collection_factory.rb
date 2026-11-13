FactoryBot.define do
  factory :product_collection, class: Spree::ProductCollection do
    product
    collection

    position { 1 }
    source { 'manual' }

    trait :rule do
      source { 'rule' }
    end
  end
end
