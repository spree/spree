FactoryBot.define do
  factory :shipping_category, class: Spree::ShippingCategory do
    sequence(:name) { |n| "ShippingCategory #{n}" }
  end

  factory :digital_shipping_category, class: Spree::ShippingCategory do
    name { 'Digital' }
  end
end
