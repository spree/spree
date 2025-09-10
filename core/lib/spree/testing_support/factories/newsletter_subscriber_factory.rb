FactoryBot.define do
  factory :newsletter_subscriber, class: Spree::NewsletterSubscriber do
    email { FFaker::Internet.unique.email }
    verified_at { nil }

    trait :with_user do
      association :user, factory: :user
    end

    trait :verified do
      verified_at { Time.current }
    end

    trait :unverified do
      verified_at { nil }
    end
  end
end
