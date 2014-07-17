FactoryGirl.define do
  factory :refund, class: Spree::Refund do
    amount 100.00
    transaction_id 'TEST123'
    association(:payment, state: 'completed')
    association(:reason, factory: :refund_reason)
  end

  factory :refund_reason, class: Spree::RefundReason do
    sequence(:name) { |n| "Refund for return ##{n}" }
  end
end
