FactoryBot.define do
  factory :payment_method, class: Spree::PaymentMethod do
    type { 'Spree::PaymentMethod' }
    sequence(:name) { |n| "Test #{n}" }
    store { Spree::Store.find_by(default: true) || association(:store) }
  end

  factory :check_payment_method, parent: :payment_method, class: Spree::PaymentMethod::Check do
    type { 'Spree::PaymentMethod::Check' }
    sequence(:name) { |n| "Check #{n}" }
  end

  factory :credit_card_payment_method, parent: :payment_method, class: Spree::Gateway::Bogus do
    type { 'Spree::Gateway::Bogus' }
    sequence(:name) { |n| "Credit Card #{n}" }
  end

  factory :simple_credit_card_payment_method, parent: :credit_card_payment_method

  factory :store_credit_payment_method, parent: :payment_method, class: Spree::PaymentMethod::StoreCredit do
    type          { 'Spree::PaymentMethod::StoreCredit' }
    sequence(:name) { |n| "Store Credit #{n}" }
    description   { 'Store Credit' }
    active        { true }
    auto_capture  { true }
  end

  factory :custom_payment_method, parent: :payment_method, class: Spree::Gateway::CustomPaymentSourceMethod do
    type { 'Spree::Gateway::CustomPaymentSourceMethod' }
    sequence(:name) { |n| "Custom #{n}" }
  end

  factory :bogus_payment_method, parent: :credit_card_payment_method
end
