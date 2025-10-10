FactoryBot.define do
  factory :product_property, class: Spree::ProductProperty do
    product { create(:product, stores: [Spree::Store.default]) }
    value { "val-#{rand(50)}" }
    property
  end
end
