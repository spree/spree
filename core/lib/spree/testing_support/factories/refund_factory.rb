FactoryBot.define do
  sequence(:refund_transaction_id) { |n| "fake-refund-transaction-#{n}" }

  factory :refund, class: Spree::Refund do
    amount         { 100.00 }
    transaction_id { generate(:refund_transaction_id) }
    association(:payment, state: 'completed')
    association(:reason, factory: :refund_reason)
  end

  factory :default_refund_reason, class: Spree::RefundReason do
    name    { 'Return processing' }
    active  { true }
    mutable { false }
  end

  factory :refund_reason, class: Spree::RefundReason do
    sequence(:name) { |n| "Refund for return ##{n}" }
    active  { true }
    mutable { false }
  end
end
