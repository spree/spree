FactoryGirl.define do
  factory :return_authorization, class: Spree::ReturnAuthorization do
    number '100'
    amount 100.00
    association(:order, factory: :shipped_order)
    reason 'no particular reason'
    state 'received'
  end

  factory :new_return_authorization, class: Spree::ReturnAuthorization do
    association(:order, factory: :shipped_order)
  end
end
