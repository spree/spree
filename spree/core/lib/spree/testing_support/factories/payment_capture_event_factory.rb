FactoryBot.define do
  factory :payment_capture_event, class: Spree::PaymentCaptureEvent do
    payment
    amount { 10.0 }
    status { 'completed' }

    trait :requested do
      status { 'requested' }
      transaction_id { "capture-#{SecureRandom.hex(6)}" }
    end

    trait :failed do
      status { 'failed' }
    end
  end
end
