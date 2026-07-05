FactoryBot.define do
  factory :store_credit_auth_event, class: Spree::StoreCreditEvent do
    association :store_credit, factory: :store_credit
    action             { Spree::StoreCredit::AUTHORIZE_ACTION }
    amount             { 100.00 }
    authorization_code { "#{store_credit.id}-SC-20140602164814476128" }
  end
end
