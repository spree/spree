FactoryBot.define do
  factory :store_product, class: Spree::StoreProduct do
    store
    product
  end
end
