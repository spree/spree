FactoryBot.define do
  factory :gift_card_batch, class: Spree::GiftCardBatch do
    store { Spree::Store.default || create(:store) }
  end
end
