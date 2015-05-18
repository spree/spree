FactoryGirl.define do
  sequence(:refund_transaction_id) { |n| "fake-refund-transaction-#{n}"}

  factory :refund, class: Spree::Refund do
    amount 100
    transaction_id { generate(:refund_transaction_id) }
    association(:payment, amount: 100, state: 'completed')
    association(:reason, factory: :refund_reason)
  end

  factory :refund_reason, class: Spree::RefundReason do
    sequence(:name) { |n| "Refund for return ##{n}" }
  end
end
