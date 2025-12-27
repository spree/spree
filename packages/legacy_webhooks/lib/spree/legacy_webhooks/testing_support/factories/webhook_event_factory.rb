FactoryBot.define do
  factory :webhook_event, aliases: [:event], class: Spree::Webhooks::Event do
    subscriber

    execution_time { rand(1..99_999) }
    name { 'order.canceled' }
    request_errors { '' }
    sequence(:url) { |n| "https://www.url#{n}.com/" }

    trait :failed do
      response_code { '500' }
      success { false }
    end

    trait :successful do
      response_code { '200' }
      success { true }
    end

    trait :blank do
      execution_time { nil }
      request_errors { nil }
      subscriber_id { nil }
      url { nil }
    end
  end
end
