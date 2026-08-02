FactoryBot.define do
  # Delivery methods are worldwide by default — geographic restriction is
  # opt-in via an explicit :delivery_zone (empty zone list = no restriction).
  factory :base_delivery_method, aliases: [:base_shipping_method], class: Spree::DeliveryMethod do
    name       { 'UPS Ground' }
    code       { 'UPS_GROUND' }
    display_on { 'both' }
    store      { Spree::Store.find_by(default: true) || association(:store) }

    factory :delivery_method, aliases: [:shipping_method], class: Spree::DeliveryMethod do
      association(:calculator, factory: :shipping_calculator, strategy: :build)
    end

    factory :free_delivery_method, aliases: [:free_shipping_method], class: Spree::DeliveryMethod do
      association(:calculator, factory: :shipping_no_amount_calculator, strategy: :build)
    end

    factory :digital_delivery_method, aliases: [:digital_shipping_method], class: Spree::DeliveryMethod do
      fulfillment_type { 'digital' }
      fulfillment_provider { 'Spree::FulfillmentProvider::Digital' }
      association(:calculator, factory: :digital_shipping_calculator, strategy: :build)
    end

    factory :pickup_delivery_method, class: Spree::DeliveryMethod do
      name { 'Store pickup' }
      code { 'PICKUP' }
      fulfillment_type { 'pickup' }
      fulfillment_provider { 'Spree::FulfillmentProvider::Pickup' }
      association(:calculator, factory: :shipping_no_amount_calculator, strategy: :build)
    end

    factory :pickup_point_delivery_method, class: Spree::DeliveryMethod do
      name { 'Parcel locker' }
      code { 'PICKUP_POINT' }
      fulfillment_type { 'pickup_point' }
      fulfillment_provider { 'Spree::FulfillmentProvider::PickupPoint' }
      association(:calculator, factory: :shipping_no_amount_calculator, strategy: :build)
    end
  end
end
