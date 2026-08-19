FactoryBot.define do
  factory :stripe_gateway, parent: :payment_method, class: 'SpreeStripe::Gateway' do
    name { 'Stripe' }
    type { 'SpreeStripe::Gateway' }

    preferences do
      {
        publishable_key: ENV.fetch('STRIPE_PUBLISHABLE_KEY', 'pk_test_1234567890'),
        secret_key: ENV.fetch('STRIPE_SECRET_KEY', 'sk_test_1234567890')
      }
    end

    trait :with_webhook_signing_secret do
      preferences do
        {
          publishable_key: ENV.fetch('STRIPE_PUBLISHABLE_KEY', 'pk_test_1234567890'),
          secret_key: ENV.fetch('STRIPE_SECRET_KEY', 'sk_test_1234567890'),
          webhook_endpoint_id: 'we_test_1234567890',
          webhook_signing_secret: 'whsec_test_1234567890'
        }
      end
    end
  end
end
