FactoryBot.define do
  factory :store_credit_category, class: Spree::StoreCreditCategory do
    name { 'Exchange' }
  end

  factory :store_credit_gift_card_category, class: Spree::StoreCreditCategory do
    name { Spree::StoreCreditCategory::GIFT_CARD_CATEGORY_NAME }
  end
end
