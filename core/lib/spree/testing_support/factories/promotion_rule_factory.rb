FactoryBot.define do
  factory :promotion_rule, class: Spree::PromotionRule do
    association :promotion
  end
end
