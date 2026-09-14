FactoryBot.define do
  factory :api_key, class: Spree::ApiKey do
    sequence(:name) { |n| "API key #{n}" }
    key_type { 'publishable' }
    store

    trait :publishable do
      key_type { 'publishable' }
    end

    trait :secret do
      key_type { 'secret' }
      scopes { ['write_all'] }
    end

    trait :revoked do
      revoked_at { Time.current }
    end
  end
end
