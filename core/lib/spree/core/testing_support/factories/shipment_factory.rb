FactoryGirl.define do
  factory :shipment, :class => Spree::Shipment do
    order { Factory(:order) }
    shipping_method { Factory(:shipping_method) }
    tracking 'U10000'
    number '100'
    cost 100.00
    address { Factory(:address) }
    state 'pending'
  end
end
