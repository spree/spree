FactoryBot.define do
  factory :product_property, class: Spree::ProductProperty do
    product
    property
  end
end
