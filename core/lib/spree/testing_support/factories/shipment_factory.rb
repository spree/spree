FactoryGirl.define do
  factory :shipment, :class => Spree::Shipment do
    order { FactoryGirl.create(:order) }
    tracking 'U10000'
    number '100'
    cost 100.00
    address { FactoryGirl.create(:address) }
    state 'pending'
    stock_location {FactoryGirl.create(:stock_location)}
    stock_location_id {stock_location.id}

    after(:create) do |shipment, evalulator|
      shipment.add_shipping_method(create(:shipping_method), true)

      shipment.order.line_items.each do |line_item|
        line_item.quantity.times { shipment.inventory_units.create(:variant_id => line_item.variant) }
      end
    end
  end
end
