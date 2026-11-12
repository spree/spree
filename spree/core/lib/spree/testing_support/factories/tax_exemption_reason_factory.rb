FactoryBot.define do
  factory :tax_exemption_reason, class: Spree::TaxExemptionReason do
    store { Spree::Store.find_by(default: true) || association(:store) }
    sequence(:name) { |n| "Tax Exemption Reason #{n}" }
    sequence(:code) { |n| "REASON_#{n}" }
    active { true }
  end
end
