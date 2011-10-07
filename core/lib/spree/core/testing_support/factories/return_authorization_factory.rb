FactoryGirl.define do
  factory :return_authorization, :class => Spree::ReturnAuthorization do
    number '100'
    amount 100.00
    #order { Factory(:order) }
    order { Factory(:order_with_inventory_unit_shipped) }
    reason 'no particular reason'
    state 'received'
  end
end
