FactoryBot.define do
  factory :return_reason, class: Spree::ReturnReason do
    sequence(:name) { |n| "Return Reason #{n}" }
    active { true }
    mutable { true }
  end

  factory :claim_reason, class: Spree::ClaimReason do
    sequence(:name) { |n| "Claim Reason #{n}" }
    active { true }
    mutable { true }
  end
end
