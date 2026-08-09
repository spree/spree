FactoryBot.define do
  factory :stripe_payment_session, class: 'Spree::PaymentSessions::Stripe' do
    transient do
      owner { create(:order_with_line_items) }
    end

    cart { owner if owner.is_a?(Spree::Cart) }
    order { owner unless owner.is_a?(Spree::Cart) }
    payment_method { create(:stripe_gateway, store: owner.store) }
    amount { owner.total }
    currency { owner.currency }
    status { 'pending' }
    external_id { "pi_test_#{SecureRandom.hex(12)}" }
    external_data { { 'client_secret' => "pi_secret_#{SecureRandom.hex(8)}" } }

    trait :with_customer do
      customer { owner.customer || create(:customer) }
      customer_external_id { "cus_#{SecureRandom.hex(8)}" }
    end

    trait :with_ephemeral_key do
      external_data do
        {
          'client_secret' => "pi_secret_#{SecureRandom.hex(8)}",
          'ephemeral_key_secret' => "ek_test_#{SecureRandom.hex(8)}"
        }
      end
    end

    trait :processing do
      status { 'processing' }
    end

    trait :completed do
      status { 'completed' }
    end

    trait :failed do
      status { 'failed' }
    end
  end

  factory :stripe_payment_setup_session, class: 'Spree::PaymentSetupSessions::Stripe' do
    customer { create(:customer) }
    payment_method { create(:stripe_gateway) }
    status { 'pending' }
    external_id { "seti_test_#{SecureRandom.hex(12)}" }
    external_client_secret { "seti_secret_#{SecureRandom.hex(8)}" }
  end
end
