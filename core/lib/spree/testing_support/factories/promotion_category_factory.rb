FactoryGirl.define do
  factory :promotion_category, class: Spree::PromotionCategory do
    sequence(:name, &'Promotion Category %d'.method(:%))
  end
end
