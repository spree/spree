FactoryBot.define do
  factory :delivery_rate, aliases: [:shipping_rate], class: Spree::DeliveryRate do
    cost { BigDecimal(10) }
    delivery_method
    fulfillment
  end
end
