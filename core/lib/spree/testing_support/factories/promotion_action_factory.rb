FactoryBot.define do
  factory :promotion_action, class: Spree::PromotionAction do
    association :promotion
  end
end
