FactoryBot.define do
  factory :user_identity, class: Spree::UserIdentity do
    association(:user, factory: :user)
    provider { 'email' }
    sequence(:uid) { |n| "user_#{n}" }
    info { { email: user.email } }
    access_token { nil }
    refresh_token { nil }
    expires_at { nil }

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end
