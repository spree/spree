FactoryGirl.define do
  factory :inventory_unit, class: Spree::InventoryUnit do
    line_item
    variant { line_item.variant }
    state 'on_hand'
    quantity 1
    association(:shipment, factory: :shipment, state: 'pending')
    # return_authorization
  end
end
