FactoryBot.define do
  factory :tax_rate, class: Spree::TaxRate do
    name { "TaxRate - #{rand(999_999)}" }
    country_iso { 'US' }
    tax_category
    amount { 0.1 }

    # Taxes every country — what a single-market store configures.
    trait :worldwide do
      country_iso { nil }
    end
  end
end
