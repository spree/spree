FactoryBot.define do
  factory :delivery_profile, class: Spree::DeliveryProfiles::Shipping do
    sequence(:name) { |n| "Delivery Profile ##{n}" }
    store { Spree::Store.find_by(default: true) || association(:store) }

    factory :digital_delivery_profile, class: Spree::DeliveryProfiles::Digital do
    end
  end
end
