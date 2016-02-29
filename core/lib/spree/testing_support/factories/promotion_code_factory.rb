FactoryGirl.define do
  factory :promotion_code, class: 'Spree::PromotionCode' do
    promotion
    value { generate(:random_code) }
  end
end
