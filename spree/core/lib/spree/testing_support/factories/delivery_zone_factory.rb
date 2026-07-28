FactoryBot.define do
  factory :delivery_zone, class: Spree::DeliveryZone do
    sequence(:name) { |n| "Delivery Zone ##{n}" }
    description { generate(:random_string) }

    factory :delivery_zone_with_country do
      transient do
        country { create(:country) }
      end

      after(:create) do |zone, evaluator|
        create(:delivery_zone_member, delivery_zone: zone, member_type: 'country', country: evaluator.country)
      end
    end
  end

  factory :delivery_zone_member, class: Spree::DeliveryZoneMember do
    delivery_zone
    member_type { 'country' }
    country
  end
end
