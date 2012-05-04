FactoryGirl.define do
  factory :shipment, :class => Spree::Shipment do
    order { FactoryGirl.create(:order) }
    shipping_method { FactoryGirl.create(:shipping_method) }
    tracking 'U10000'
    number '100'
    cost 100.00
    address { FactoryGirl.create(:address) }
    state 'pending'
  end
end
