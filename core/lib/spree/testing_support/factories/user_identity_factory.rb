FactoryBot.define do
  factory :user_identity, class: Spree::UserIdentity do
    association(:user, factory: :user)
    provider { 'email' }
    sequence(:uid) { |n| "user_#{n}" }
    info { { email: user.email } }
    access_token { nil }
    refresh_token { nil }
    expires_at { nil }

    trait :google do
      provider { 'google' }
      sequence(:uid) { |n| "google_#{n}" }
      access_token { 'google_access_token' }
      refresh_token { 'google_refresh_token' }
      expires_at { 1.hour.from_now }
      info do
        {
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name
        }
      end
    end

    trait :facebook do
      provider { 'facebook' }
      sequence(:uid) { |n| "facebook_#{n}" }
      access_token { 'facebook_access_token' }
      info do
        {
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name
        }
      end
    end

    trait :github do
      provider { 'github' }
      sequence(:uid) { |n| "github_#{n}" }
      access_token { 'github_access_token' }
      info do
        {
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name
        }
      end
    end

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end
