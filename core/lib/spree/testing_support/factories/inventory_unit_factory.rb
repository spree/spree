FactoryGirl.define do
  factory :inventory_unit, class: Spree::InventoryUnit do
    variant
    order
    line_item
    state 'on_hand'
    association(:shipment, factory: :shipment, state: 'pending')
    # return_authorization
  end
end
