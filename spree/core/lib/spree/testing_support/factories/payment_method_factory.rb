FactoryBot.define do
  factory :payment_method, class: Spree::PaymentMethod do
    type { 'Spree::PaymentMethod' }
    name { 'Test' }
    store { Spree::Store.default || association(:store) }
  end

  factory :check_payment_method, parent: :payment_method, class: Spree::PaymentMethod::Check do
    type { 'Spree::PaymentMethod::Check' }
    name { 'Check' }
  end

  factory :credit_card_payment_method, parent: :payment_method, class: Spree::Gateway::Bogus do
    type { 'Spree::Gateway::Bogus' }
    name { 'Credit Card' }
  end

  factory :simple_credit_card_payment_method, parent: :credit_card_payment_method

  factory :store_credit_payment_method, parent: :payment_method, class: Spree::PaymentMethod::StoreCredit do
    type          { 'Spree::PaymentMethod::StoreCredit' }
    name          { 'Store Credit' }
    description   { 'Store Credit' }
    active        { true }
    auto_capture  { true }
  end

  factory :custom_payment_method, parent: :payment_method, class: Spree::Gateway::CustomPaymentSourceMethod do
    type { 'Spree::Gateway::CustomPaymentSourceMethod' }
    name { 'Custom' }
  end

  factory :bogus_payment_method, parent: :credit_card_payment_method
end
