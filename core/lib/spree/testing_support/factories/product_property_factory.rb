FactoryBot.define do
  factory :product_property, class: Spree::ProductProperty do
    product
    property
    sequence(:value) { |n| "value_#{n}" }
  end
end
