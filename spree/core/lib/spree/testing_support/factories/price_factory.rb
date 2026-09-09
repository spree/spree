FactoryBot.define do
  factory :price, class: Spree::Price do
    variant
    amount   { 19.99 }
    currency { 'USD' }

    factory :price_eur do
      currency { 'EUR' }
    end

    # A rung above the bottom of a list's ladder. Breaks need a list, so the
    # caller supplies one (docs/plans/6.0-volume-pricing.md).
    trait :quantity_break do
      min_quantity { 10 }
    end
  end
end
