FactoryGirl.define do
  factory :inventory_unit, class: Spree::InventoryUnit do
    order { create(:order_with_line_items, line_items_count: 1) }
    line_item { order.line_items.first! }
    variant { line_item.variant }
    association(:shipment, factory: :shipment, state: 'pending')
  end
end
