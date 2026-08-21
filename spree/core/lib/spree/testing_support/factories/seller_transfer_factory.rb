FactoryBot.define do
  factory :seller_transfer, class: Spree::SellerTransfer do
    seller
    store { seller.store }
    order
    amount { BigDecimal(20) }
    currency { 'USD' }
    kind { 'earning' }
    provider { 'system' }
    status { 'pending' }

    trait :completed do
      status { 'completed' }
    end

    trait :reversal do
      kind { 'refund_reversal' }
      amount { BigDecimal(-5) }
    end
  end
end
