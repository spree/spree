FactoryBot.define do
  factory :product_collection, class: Spree::ProductCollection do
    product
    collection

    position { 1 }
  end
end
