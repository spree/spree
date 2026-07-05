FactoryBot.define do
  factory :inventory_unit, class: Spree::InventoryUnit do
    variant
    order
    line_item
    state { 'on_hand' }

    association(:shipment, factory: :shipment, state: 'pending')
    # return_authorization

    # this trait usage increases build speed ~ 2x
    trait :without_assoc do
      shipment  { nil }
      order     { nil }
      line_item { nil }
    end
  end
end
