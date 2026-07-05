FactoryBot.define do
  factory :order_promotion, class: Spree::OrderPromotion do
    order
    promotion
  end
end
