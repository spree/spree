FactoryGirl.define do
  factory :adjustment do
    order { Factory(:order) }
    amount '100.0'
    label 'Shipping'
    source { Factory(:shipment) }
    eligible true
  end
end