FactoryBot.define do
  factory :product_property, class: Spree::ProductProperty do
    product
    value { "val-#{rand(50)}" }
    property
  end
end
