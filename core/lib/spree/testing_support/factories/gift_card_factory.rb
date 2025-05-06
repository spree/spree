FactoryBot.define do
  factory :gift_card, class: Spree::GiftCard do
    state { :active }
    amount { 10.00 }
    store { Spree::Store.default || create(:store) }

    trait :fully_redeemed do
      state { :redeemed }
    end
  end
end
