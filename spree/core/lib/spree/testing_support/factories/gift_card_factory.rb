FactoryBot.define do
  factory :gift_card, class: Spree::GiftCard do
    status { :active }
    amount { 10.00 }
    store { Spree::Store.default || create(:store) }

    trait :redeemed do
      status { :redeemed }
      redeemed_at { Time.current }
      amount_used { amount }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
