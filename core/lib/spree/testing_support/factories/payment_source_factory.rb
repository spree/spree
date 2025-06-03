FactoryBot.define do
  factory :payment_source, class: Spree::PaymentSource do
    association(:payment_method, factory: :custom_payment_method)
  end
end
