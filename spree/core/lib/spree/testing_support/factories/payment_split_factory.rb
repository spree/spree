FactoryBot.define do
  factory :payment_split, class: Spree::PaymentSplit do
    payment
    order
    currency { 'USD' }
    authorized_amount { BigDecimal(10) }
    captured_amount { BigDecimal(0) }
    refunded_amount { BigDecimal(0) }
  end
end
