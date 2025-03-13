FactoryBot.define do
  factory :promotion_action, class: Spree::PromotionAction do
    association :promotion
  end

  factory :promotion_action_create_adjustment, class: Spree::Promotion::Actions::CreateAdjustment do
    association :promotion
    association :calculator, factory: :flat_rate_calculator
  end
end
