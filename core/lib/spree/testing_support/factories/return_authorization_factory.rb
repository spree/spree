FactoryGirl.define do
  factory :return_authorization, class: Spree::ReturnAuthorization do
    number '100'
    association(:order, factory: :shipped_order)
    association(:reason, factory: :return_authorization_reason)
    memo 'Items were broken'
    state 'received'
  end

  factory :new_return_authorization, class: Spree::ReturnAuthorization do
    association(:order, factory: :shipped_order)
    association(:reason, factory: :return_authorization_reason)
  end

  factory :return_item, class: Spree::ReturnItem do
    association(:return_authorization, factory: :return_authorization)
    association(:inventory_unit, factory: :inventory_unit, state: 'shipped')
  end

  factory :return_authorization_reason, class: Spree::ReturnAuthorizationReason do
    sequence(:name) { |n| "Defect ##{n}" }
  end
end
