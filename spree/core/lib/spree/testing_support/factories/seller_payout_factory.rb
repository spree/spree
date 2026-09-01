FactoryBot.define do
  factory :seller_payout, class: Spree::SellerPayout do
    seller
    store { seller.store }
    amount { BigDecimal(20) }
    currency { 'USD' }
    provider { Spree::PayoutProvider::System.provider_key }
    status { 'pending' }

    trait :completed do
      status { 'completed' }
    end
  end
end
