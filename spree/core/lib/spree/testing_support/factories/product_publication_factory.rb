FactoryBot.define do
  factory :product_publication, class: Spree::ProductPublication do
    product
    channel { product&.store&.default_channel || association(:channel) }
  end
end
