FactoryGirl.define do
  factory :shipment, class: Spree::Shipment do
    tracking 'U10000'
    number '100'
    state 'pending'
    order
    address
    stock_location

    after(:create) do |shipment, evalulator|
      shipping_method = create(:shipping_method)
      shipping_method.calculator.preferred_amount = 100
      shipment.add_shipping_method(shipping_method, true)

      shipment.order.line_items.each do |line_item|
        line_item.quantity.times { shipment.inventory_units.create(variant_id: line_item.variant_id) }
      end
    end
  end
end
