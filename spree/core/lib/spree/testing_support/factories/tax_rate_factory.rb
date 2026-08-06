FactoryBot.define do
  factory :tax_rate, class: Spree::TaxRate do
    name { "TaxRate - #{rand(999_999)}" }
    country { Spree::Country.find_by(iso: 'US') || association(:country) }
    tax_category
    amount { 0.1 }

    # Taxes every country — what a single-market store configures.
    trait :worldwide do
      country { nil }
    end
  end
end
