FactoryGirl.define do
  factory :shipment, :class => Spree::Shipment do
    order { FactoryGirl.create(:order) }
    tracking 'U10000'
    number '100'
    cost 100.00
    address { FactoryGirl.create(:address) }
    state 'pending'
    after(:create) do |shipment, evalulator|
      shipment.add_shipping_method(create(:shipping_method), true)
    end
    stock_location {FactoryGirl.create(:stock_location)}
    stock_location_id {stock_location.id}
    
  end
end
