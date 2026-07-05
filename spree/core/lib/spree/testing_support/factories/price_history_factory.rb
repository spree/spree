FactoryBot.define do
  factory :price_history, class: Spree::PriceHistory do
    price
    variant { price.variant }
    amount { price.amount }
    currency { price.currency }
    recorded_at { Time.current }
  end
end
