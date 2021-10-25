FactoryBot.define do
  factory :webhook_subscriber, aliases: [:subscriber], class: Spree::Webhooks::Subscriber do
    trait :active do
      active { true }
      sequence(:url) { |n| "https://www.url#{n}.com/" }
    end
  end
end
