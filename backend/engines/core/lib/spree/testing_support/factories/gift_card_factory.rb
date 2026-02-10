FactoryBot.define do
  factory :gift_card, class: Spree::GiftCard do
    state { :active }
    amount { 10.00 }
    store { Spree::Store.default || create(:store) }

    trait :redeemed do
      state { :redeemed }
      redeemed_at { Time.current }
      amount_used { amount }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
