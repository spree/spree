FactoryBot.define do
  factory :product_publication, class: Spree::ProductPublication do
    product
    store    { product&.stores&.first || Spree::Store.default || association(:store) }
    channel  { store&.default_channel }
  end
end
