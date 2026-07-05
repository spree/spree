FactoryBot.define do
  factory :payment_setup_session, class: 'Spree::PaymentSetupSession' do
    customer { create(:user) }
    payment_method { create(:credit_card_payment_method) }
    status { 'pending' }
    external_id { "seti_test_#{SecureRandom.hex(12)}" }
    external_client_secret { "seti_secret_#{SecureRandom.hex(12)}" }
    external_data { {} }

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
      payment_source { create(:credit_card, user: customer) }
    end

    trait :failed do
      status { 'failed' }
    end

    trait :canceled do
      status { 'canceled' }
    end

    trait :expired do
      status { 'expired' }
    end
  end
end
