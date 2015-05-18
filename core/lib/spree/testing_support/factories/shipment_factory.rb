FactoryGirl.define do
  factory :shipment, class: Spree::Shipment do
    tracking 'U10000'
    cost 100.00
    state 'pending'
    order
    stock_location

    after(:create) do |shipment, evalulator|
      shipment.add_shipping_method(create(:shipping_method), true)

      shipment.order.line_items.each do |line_item|
        line_item.quantity.times do
          shipment.inventory_units.create!(
            order:     line_item.order,
            variant:   line_item.variant,
            line_item: line_item
          )
        end
      end
    end
  end
end
