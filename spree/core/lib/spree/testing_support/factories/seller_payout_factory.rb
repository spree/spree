FactoryBot.define do
  factory :seller_payout, class: Spree::SellerPayout do
    seller
    amount { BigDecimal(20) }
    currency { 'USD' }
    provider { 'system' }
    status { 'pending' }

    trait :completed do
      status { 'completed' }
    end
  end
end
