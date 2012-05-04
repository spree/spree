FactoryGirl.define do
  factory :return_authorization, :class => Spree::ReturnAuthorization do
    number '100'
    amount 100.00
    #order { FactoryGirl.create(:order) }
    order { FactoryGirl.create(:order_with_inventory_unit_shipped) }
    reason 'no particular reason'
    state 'received'
  end
end
