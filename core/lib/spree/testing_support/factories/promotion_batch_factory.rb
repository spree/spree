FactoryBot.define do
  factory :promotion_batch, class: Spree::PromotionBatch do
    association :template_promotion, factory: :promotion
  end
end
