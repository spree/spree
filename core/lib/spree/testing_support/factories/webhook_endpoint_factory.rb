# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_endpoint, class: Spree::WebhookEndpoint do
    store
    sequence(:url) { |n| "https://example.com/webhooks/#{n}" }
    active { true }
    subscriptions { [] }

    trait :inactive do
      active { false }
    end

    trait :with_subscriptions do
      subscriptions { %w[order.created order.completed product.created] }
    end

    trait :all_events do
      subscriptions { ['*'] }
    end
  end
end
