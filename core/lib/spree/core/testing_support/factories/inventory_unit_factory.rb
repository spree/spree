FactoryGirl.define do
  factory :inventory_unit, :class => Spree::InventoryUnit do
    variant { Factory(:variant) }
    order { Factory(:order) }
    state 'sold'
    shipment { Factory(:shipment, :state => 'pending') }
    #return_authorization { Factory(:return_authorization) }
  end
end
