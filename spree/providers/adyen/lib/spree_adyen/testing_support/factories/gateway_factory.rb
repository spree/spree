FactoryBot.define do
  factory :adyen_gateway, parent: :payment_method, class: 'SpreeAdyen::Gateway' do
    sequence(:name) { |n| "Adyen #{n}" }
    type { 'SpreeAdyen::Gateway' }

    preferences do
      {
        api_key: ENV.fetch('ADYEN_API_KEY', 'adyen_api_key_test'),
        merchant_account: ENV.fetch('ADYEN_MERCHANT_ACCOUNT', 'SpreeTestECOM'),
        test_mode: true
      }
    end

    trait :configured do
      after(:build) do |gateway|
        gateway.preferred_client_key = 'test_CLIENTKEY'
        gateway.preferred_hmac_key = '44782DEF547AAA06C910C43932B1EB0C71FC68D9D0C057550C48EC2ACF6BA056'
        gateway.preferred_webhook_id = 'WBHK00000000000000000000'
      end
    end
  end
end
