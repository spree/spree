FactoryBot.define do
  factory :delivery_origin_group, class: Spree::DeliveryOriginGroup do
    delivery_profile
  end
end
