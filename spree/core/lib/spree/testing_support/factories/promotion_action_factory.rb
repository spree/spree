FactoryBot.define do
  factory :promotion_action, class: Spree::PromotionAction do
    association :promotion
  end

  factory :promotion_action_create_adjustment, class: Spree::Promotion::Actions::CreateAdjustment do
    association :promotion
    association :calculator, factory: :flat_rate_calculator
  end

  factory :promotion_action_create_line_items, class: Spree::Promotion::Actions::CreateLineItems do
    association :promotion
  end
end
