FactoryBot.define do
  factory :product_translation, class: Spree::Product::Translation do
    sequence(:name) { |n| "Product #{n}" }
    description { generate(:random_description) }
  end
end
