FactoryGirl.define do
  factory :refund, class: Spree::Refund do
    amount 100.00
    transaction_id 'TEST123'
    association(:payment, state: 'completed')
  end
end
