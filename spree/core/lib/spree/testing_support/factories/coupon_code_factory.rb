FactoryBot.define do
  factory :coupon_code, class: Spree::CouponCode do
    sequence(:code) { |n| "PROMO#{n}" }
    state { :unused }
    promotion
  end
end
