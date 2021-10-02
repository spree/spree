FactoryBot.define do
  factory :shipping_rate, class: Spree::ShippingRate do
    cost { BigDecimal(10) }
    shipping_method
    shipment
  end
end
