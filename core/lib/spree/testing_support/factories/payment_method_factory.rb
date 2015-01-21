FactoryGirl.define do
  factory :check_payment_method, class: Spree::PaymentMethod::Check do
    name 'Check'
  end

  factory :credit_card_payment_method, class: Spree::Gateway::Bogus do
    name 'Credit Card'
  end

  # authorize.net was moved to spree_gateway.
  # Leaving this factory in place with bogus in case anyone is using it.
  factory :simple_credit_card_payment_method, class: Spree::Gateway::BogusSimple do
    name 'Credit Card'
  end
end
