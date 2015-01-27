FactoryGirl.define do
  factory :promotion_code, class: 'Spree::PromotionCode' do
    promotion
    value "promocode"
    starts_at "2015-01-01 00:00:00"
    expires_at "2050-12-31 23:59:59"
    usage_limit 1
  end
end
