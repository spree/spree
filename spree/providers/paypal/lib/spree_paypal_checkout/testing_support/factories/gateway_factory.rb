FactoryBot.define do
  factory :paypal_checkout_gateway, parent: :payment_method, class: 'SpreePaypalCheckout::Gateway' do
    sequence(:name) { |n| "PayPal #{n}" }
    type { 'SpreePaypalCheckout::Gateway' }

    preferences do
      {
        client_id: ENV.fetch('PAYPAL_CLIENT_ID', 'paypal_client_id_test'),
        client_secret: ENV.fetch('PAYPAL_CLIENT_SECRET', 'paypal_client_secret_test'),
        test_mode: true
      }
    end

    trait :with_webhook do
      after(:build) { |gateway| gateway.preferred_webhook_id = 'WH-TEST-1234567890' }
    end
  end
end
