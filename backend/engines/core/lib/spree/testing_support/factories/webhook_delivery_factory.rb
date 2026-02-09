# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_delivery, class: Spree::WebhookDelivery do
    webhook_endpoint
    event_name { 'order.created' }
    payload { { event: 'order.created', data: { id: 1 } } }

    trait :pending do
      response_code { nil }
      execution_time { nil }
      success { nil }
      delivered_at { nil }
    end

    trait :successful do
      response_code { 200 }
      execution_time { 150 }
      success { true }
      delivered_at { Time.current }
    end

    trait :failed do
      response_code { 500 }
      execution_time { 200 }
      success { false }
      delivered_at { Time.current }
    end

    trait :timeout do
      response_code { nil }
      error_type { 'timeout' }
      execution_time { 30_000 }
      success { false }
      request_errors { 'execution expired' }
      delivered_at { Time.current }
    end

    trait :connection_error do
      response_code { nil }
      error_type { 'connection_error' }
      execution_time { 100 }
      success { false }
      request_errors { 'Connection refused' }
      delivered_at { Time.current }
    end
  end
end
