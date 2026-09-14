FactoryBot.define do
  # Delivery methods are worldwide by default — geographic restriction is
  # opt-in via an explicit :delivery_zone (empty zone list = no restriction).
  factory :base_delivery_method, aliases: [:base_shipping_method], class: Spree::DeliveryMethod do
    sequence(:name) { |n| "UPS Ground #{n}" }
    sequence(:code) { |n| "UPS_GROUND_#{n}" }
    store { Spree::Store.find_by(default: true) || association(:store) }
    delivery_profile { store.default_delivery_profile || association(:delivery_profile, store: store) }

    factory :delivery_method, aliases: [:shipping_method], class: Spree::DeliveryMethod do
      association(:calculator, factory: :shipping_calculator, strategy: :build)
    end

    factory :free_delivery_method, aliases: [:free_shipping_method], class: Spree::DeliveryMethod do
      association(:calculator, factory: :shipping_no_amount_calculator, strategy: :build)
    end

    factory :digital_delivery_method, aliases: [:digital_shipping_method], class: Spree::DeliveryMethod do
      fulfillment_provider { 'Spree::FulfillmentProvider::Digital' }
      delivery_profile do
        Spree::DeliveryProfiles::Digital.find_by(store: store) ||
          association(:digital_delivery_profile, store: store)
      end
      association(:calculator, factory: :digital_shipping_calculator, strategy: :build)
    end

    factory :pickup_delivery_method, class: Spree::DeliveryMethod do
      sequence(:name) { |n| "Store pickup #{n}" }
      sequence(:code) { |n| "PICKUP_#{n}" }
      fulfillment_provider { 'Spree::FulfillmentProvider::Pickup' }
      association(:calculator, factory: :shipping_no_amount_calculator, strategy: :build)
    end

    factory :pickup_point_delivery_method, class: Spree::DeliveryMethod do
      sequence(:name) { |n| "Parcel locker #{n}" }
      sequence(:code) { |n| "PICKUP_POINT_#{n}" }
      fulfillment_provider { 'Spree::FulfillmentProvider::PickupPoint' }
      association(:calculator, factory: :shipping_no_amount_calculator, strategy: :build)
    end
  end

  factory :delivery_method_service, class: Spree::DeliveryMethodService do
    delivery_method
    carrier { 'UPS' }
    service { 'Ground' }
  end
end
