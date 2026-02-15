FactoryBot.define do
  factory :payment_session, class: 'Spree::PaymentSession' do
    order
    payment_method { create(:credit_card_payment_method, stores: [order.store]) }
    amount { order.total }
    currency { order.currency }
    status { 'pending' }
    external_id { "ps_test_#{SecureRandom.hex(12)}" }
    external_data { {} }

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :canceled do
      status { 'canceled' }
    end

    trait :expired do
      status { 'expired' }
      expires_at { 1.hour.ago }
    end

    trait :with_expiration do
      expires_at { 24.hours.from_now }
    end

    trait :with_customer do
      customer { order.user || create(:user) }
    end

    factory :bogus_payment_session, class: 'Spree::PaymentSession::Bogus' do
      type { 'Spree::PaymentSession::Bogus' }
      payment_method { create(:bogus_payment_method, stores: [order.store]) }
      external_id { "bogus_#{SecureRandom.hex(12)}" }
      external_data { { 'client_secret' => "bogus_secret_#{SecureRandom.hex(8)}" } }
    end
  end
end
