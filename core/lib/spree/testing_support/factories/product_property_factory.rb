FactoryBot.define do
  factory :product_property, class: Spree::ProductProperty do
    product { create(:product, stores: [create(:store)]) }
    property
  end
end
