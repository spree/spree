# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_endpoint, class: Spree::WebhookEndpoint do
    store
    sequence(:name) { |n| "Endpoint #{n}" }
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

    trait :auto_disabled do
      active { false }
      disabled_at { Time.current }
      disabled_reason { 'Automatically disabled after repeated delivery failures' }
    end
  end
end
