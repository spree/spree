FactoryGirl.define do
  factory :return_authorization, class: Spree::ReturnAuthorization do
    number '100'
    association(:order, factory: :shipped_order)
    reason 'no particular reason'
    state 'received'
  end

  factory :new_return_authorization, class: Spree::ReturnAuthorization do
    association(:order, factory: :shipped_order)
  end

  factory :return_item, class: Spree::ReturnItem do
    association(:return_authorization, factory: :return_authorization)
    association(:inventory_unit, factory: :inventory_unit)
  end
end
