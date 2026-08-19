FactoryBot.define do
  sequence(:store_credits_order_number) { |n| "R1000#{n}" }

  factory :store_credit, class: Spree::StoreCredit do
    customer
    association :created_by, factory: :admin_user
    amount { 150.00 }
    currency { 'USD' }
    store { Spree::Store.default || create(:store) }
  end

  factory :store_credits_order_without_user, class: Spree::Order do
    number { generate(:store_credits_order_number) }
    bill_address
  end
end
