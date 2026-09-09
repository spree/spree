FactoryBot.define do
  factory :price_adjustment_tier, class: Spree::PriceAdjustmentTier do
    price_list
    min_quantity { 10 }
    percentage { -10 }
  end
end
