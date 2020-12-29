FactoryBot.define do
  factory :shipment, class: Spree::Shipment do
    tracking { 'U10000' }
    cost     { 100.00 }
    state    { 'pending' }
    order
    stock_location

    after(:create) do |shipment, _evalulator|
      shipment.add_shipping_method(create(:shipping_method), true)
      shipment.order.line_items.map do |line_item|
        shipment.inventory_units.create(
          order_id: shipment.order_id,
          variant_id: line_item.variant_id,
          line_item_id: line_item.id,
          quantity: line_item.quantity
        )
      end
    end
  end
end
