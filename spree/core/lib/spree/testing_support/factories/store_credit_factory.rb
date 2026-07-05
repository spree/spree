FactoryBot.define do
  sequence(:store_credits_order_number) { |n| "R1000#{n}" }

  factory :store_credit, class: Spree::StoreCredit do
    user
    association :created_by, factory: :admin_user
    association :category, factory: :store_credit_category
    amount { 150.00 }
    currency { 'USD' }
    association :credit_type, factory: :primary_credit_type
    store { Spree::Store.default || create(:store) }
  end

  factory :store_credits_order_without_user, class: Spree::Order do
    number { generate(:store_credits_order_number) }
    bill_address
  end
end
