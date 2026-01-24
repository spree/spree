FactoryBot.define do
  factory :api_key, class: Spree::ApiKey do
    name { FFaker::Lorem.word }
    key_type { 'publishable' }
    store

    trait :publishable do
      key_type { 'publishable' }
    end

    trait :secret do
      key_type { 'secret' }
    end

    trait :revoked do
      revoked_at { Time.current }
    end
  end
end
