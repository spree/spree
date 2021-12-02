FactoryBot.define do
  factory :webhook_subscriber, aliases: [:subscriber], class: Spree::Webhooks::Subscriber do
    sequence(:url) { |n| "https://www.url#{n}.com/" }

    trait :active do
      active { true }
    end

    trait :inactive do
      active { false }
    end
  end
end
