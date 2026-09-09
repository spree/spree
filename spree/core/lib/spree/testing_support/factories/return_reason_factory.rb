FactoryBot.define do
  factory :return_reason, class: Spree::ReturnReason do
    store { Spree::Store.find_by(default: true) || association(:store) }
    sequence(:name) { |n| "Return Reason #{n}" }
    active { true }
  end

  factory :claim_reason, class: Spree::ClaimReason do
    store { Spree::Store.find_by(default: true) || association(:store) }
    sequence(:name) { |n| "Claim Reason #{n}" }
    active { true }
  end

  factory :order_cancellation_reason, class: Spree::OrderCancellationReason do
    store { Spree::Store.find_by(default: true) || association(:store) }
    sequence(:name) { |n| "Order Cancellation Reason #{n}" }
    active { true }
  end
end
