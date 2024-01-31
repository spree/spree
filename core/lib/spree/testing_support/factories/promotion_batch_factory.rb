FactoryBot.define do
  factory :promotion_batch, class: Spree::PromotionBatch do
    association :template_promotion, factory: :promotion

    codes { [SecureRandom.hex(5), SecureRandom.hex(5)] }
  end
end
